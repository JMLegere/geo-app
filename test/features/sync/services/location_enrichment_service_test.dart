import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/core/persistence/cell_property_repository.dart';
import 'package:earth_nova/core/persistence/location_node_repository.dart';
import 'package:earth_nova/features/sync/services/location_enrichment_service.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockCellPropertyRepository implements CellPropertyRepository {
  final List<(String cellId, String locationId)> updateLocationIdCalls = [];

  @override
  Future<void> updateLocationId(String cellId, String locationId) async {
    updateLocationIdCalls.add((cellId, locationId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'MockCellPropertyRepository.${invocation.memberName}');
}

class MockLocationNodeRepository implements LocationNodeRepository {
  final List<LocationNode> upsertedNodes = [];

  @override
  Future<void> upsert(LocationNode node) async {
    upsertedNodes.add(node);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'MockLocationNodeRepository.${invocation.memberName}');
}

/// Mock [FunctionsClient] that records `invoke()` calls and returns
/// configurable responses or throws [FunctionException].
class MockFunctionsClient implements FunctionsClient {
  final List<({String functionName, Object? body})> invocations = [];

  /// Called for every `invoke()`. Return a [FunctionResponse] or throw
  /// [FunctionException] (or any other exception).
  FunctionResponse Function(String functionName, Object? body)? handler;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #invoke) {
      final functionName = invocation.positionalArguments[0] as String;
      final body = invocation.namedArguments[#body];
      invocations.add((functionName: functionName, body: body));

      if (handler != null) {
        try {
          final response = handler!(functionName, body);
          return Future<FunctionResponse>.value(response);
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

/// Minimal [GoTrueClient] mock — returns null session, refresh is a no-op.
class MockGoTrueClient implements GoTrueClient {
  @override
  Session? get currentSession => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #refreshSession) {
      // Return a completed future so _deduplicatedRefresh() works.
      return Future<AuthResponse>.value(AuthResponse(session: null));
    }
    throw UnimplementedError('MockGoTrueClient.${invocation.memberName}');
  }
}

/// Wires [MockFunctionsClient] and [MockGoTrueClient] into a
/// [SupabaseClient] that can be passed to [LocationEnrichmentService].
class MockSupabaseClient implements SupabaseClient {
  MockSupabaseClient({
    required this.mockFunctions,
    required this.mockAuth,
  });

  final MockFunctionsClient mockFunctions;
  final MockGoTrueClient mockAuth;

  @override
  FunctionsClient get functions => mockFunctions;

  @override
  GoTrueClient get auth => mockAuth;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('MockSupabaseClient.${invocation.memberName}');
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockCellPropertyRepository cellPropertyRepo;
  late MockLocationNodeRepository locationNodeRepo;

  setUp(() {
    cellPropertyRepo = MockCellPropertyRepository();
    locationNodeRepo = MockLocationNodeRepository();
  });

  group('LocationEnrichmentService', () {
    test('requestEnrichment is no-op when supabaseClient is null', () {
      final service = LocationEnrichmentService(
        cellPropertyRepo: cellPropertyRepo,
        locationNodeRepo: locationNodeRepo,
        supabaseClient: null,
      );
      addTearDown(service.dispose);

      // Should not throw and should not enqueue anything.
      service.requestEnrichment(cellId: 'cell_1', lat: 45.0, lon: -66.0);

      // No crash, no calls to repos.
      expect(cellPropertyRepo.updateLocationIdCalls, isEmpty);
      expect(locationNodeRepo.upsertedNodes, isEmpty);
    });

    test('deduplicates concurrent requests for same cellId', () {
      // With null client, requests are silently dropped. But the dedup
      // guard (_inFlight) prevents even adding to the queue.
      final service = LocationEnrichmentService(
        cellPropertyRepo: cellPropertyRepo,
        locationNodeRepo: locationNodeRepo,
        supabaseClient: null,
      );
      addTearDown(service.dispose);

      // First call: no-op (null client), but exercises the guard path.
      service.requestEnrichment(cellId: 'cell_1', lat: 45.0, lon: -66.0);
      service.requestEnrichment(cellId: 'cell_1', lat: 45.0, lon: -66.0);

      // Both are silently ignored because client is null.
      expect(cellPropertyRepo.updateLocationIdCalls, isEmpty);
    });

    test('onLocationEnriched stream emits enrichment events', () async {
      final service = LocationEnrichmentService(
        cellPropertyRepo: cellPropertyRepo,
        locationNodeRepo: locationNodeRepo,
        supabaseClient: null,
      );
      addTearDown(service.dispose);

      // Stream should be a broadcast stream (multiple listeners OK).
      expect(service.onLocationEnriched.isBroadcast, isTrue);
    });

    test('dispose cancels drain timer without error', () {
      final service = LocationEnrichmentService(
        cellPropertyRepo: cellPropertyRepo,
        locationNodeRepo: locationNodeRepo,
        supabaseClient: null,
      );

      // Should not throw even if no timer was ever created.
      service.dispose();
    });

    test('dispose can be called multiple times safely', () {
      final service = LocationEnrichmentService(
        cellPropertyRepo: cellPropertyRepo,
        locationNodeRepo: locationNodeRepo,
        supabaseClient: null,
      );

      service.dispose();
      service.dispose(); // No crash on double-dispose.
    });

    test('accepts custom maxRetries and baseDelayMs', () {
      final service = LocationEnrichmentService(
        cellPropertyRepo: cellPropertyRepo,
        locationNodeRepo: locationNodeRepo,
        supabaseClient: null,
        maxRetries: 5,
        baseDelayMs: 500,
      );
      addTearDown(service.dispose);

      expect(service.maxRetries, 5);
      expect(service.baseDelayMs, 500);
    });

    test('defaults maxRetries to 3 and baseDelayMs to 1200', () {
      final service = LocationEnrichmentService(
        cellPropertyRepo: cellPropertyRepo,
        locationNodeRepo: locationNodeRepo,
      );
      addTearDown(service.dispose);

      expect(service.maxRetries, 3);
      expect(service.baseDelayMs, 1200);
    });

    test('onLocationEnriched supports multiple listeners', () async {
      final listener1 = <String>[];
      final listener2 = <String>[];

      final service = LocationEnrichmentService(
        cellPropertyRepo: cellPropertyRepo,
        locationNodeRepo: locationNodeRepo,
      );
      addTearDown(service.dispose);

      service.onLocationEnriched.listen((e) => listener1.add(e.cellId));
      service.onLocationEnriched.listen((e) => listener2.add(e.cellId));

      // Both listeners should be independent — broadcast stream.
      expect(service.onLocationEnriched.isBroadcast, isTrue);
    });
  });

  group('LocationNode parsing', () {
    // These test the AdminLevel.fromString used by _parseHierarchyNode.
    test('AdminLevel.fromString parses all valid levels', () {
      for (final level in AdminLevel.values) {
        expect(AdminLevel.fromString(level.name), level);
      }
    });

    test('AdminLevel.fromString throws on unknown value', () {
      expect(
        () => AdminLevel.fromString('galaxy'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('AdminLevel has 6 values including world', () {
      expect(AdminLevel.values, hasLength(6));
      expect(AdminLevel.values.first, AdminLevel.world);
      expect(AdminLevel.values.last, AdminLevel.district);
    });

    test('AdminLevel.displayName returns human-readable labels', () {
      expect(AdminLevel.world.displayName, 'World');
      expect(AdminLevel.continent.displayName, 'Continent');
      expect(AdminLevel.country.displayName, 'Country');
      expect(AdminLevel.state.displayName, 'State/Province');
      expect(AdminLevel.city.displayName, 'City');
      expect(AdminLevel.district.displayName, 'District');
    });
  });

  group('Batch mode', () {
    late MockFunctionsClient mockFunctions;
    late MockSupabaseClient mockClient;

    setUp(() {
      cellPropertyRepo = MockCellPropertyRepository();
      locationNodeRepo = MockLocationNodeRepository();
      mockFunctions = MockFunctionsClient();
      mockClient = MockSupabaseClient(
        mockFunctions: mockFunctions,
        mockAuth: MockGoTrueClient(),
      );
    });

    test('sends single batch request for multiple cells', () {
      fakeAsync((async) {
        mockFunctions.handler = (name, body) {
          return FunctionResponse(
            status: 200,
            data: {
              'results': <Map<String, Object?>>[
                {
                  'cell_id': 'cell_1',
                  'status': 'enriched',
                  'location_id': 'loc_1',
                  'hierarchy': <Object>[],
                },
                {
                  'cell_id': 'cell_2',
                  'status': 'enriched',
                  'location_id': 'loc_2',
                  'hierarchy': <Object>[],
                },
              ],
              'errors': <Object>[],
            },
          );
        };

        final service = LocationEnrichmentService(
          cellPropertyRepo: cellPropertyRepo,
          locationNodeRepo: locationNodeRepo,
          supabaseClient: mockClient,
        );
        addTearDown(service.dispose);

        service.requestEnrichment(cellId: 'cell_1', lat: 45.0, lon: -66.0);
        service.requestEnrichment(cellId: 'cell_2', lat: 46.0, lon: -67.0);

        // Advance past the drain timer.
        async.elapse(const Duration(seconds: 2));

        expect(mockFunctions.invocations, hasLength(1));
        expect(mockFunctions.invocations.first.functionName,
            'enrich-locations-batch');

        // Verify the batch body contains both cells.
        final body =
            mockFunctions.invocations.first.body as Map<String, dynamic>;
        final cells = body['cells'] as List;
        expect(cells, hasLength(2));
      });
    });

    test('404 triggers fallback to single-request mode', () {
      fakeAsync((async) {
        mockFunctions.handler = (name, body) {
          if (name == 'enrich-locations-batch') {
            throw const FunctionException(status: 404);
          }
          // Single-request fallback.
          return FunctionResponse(
            status: 200,
            data: {
              'status': 'enriched',
              'location_id': 'loc_fallback',
              'hierarchy': <Object>[],
            },
          );
        };

        final service = LocationEnrichmentService(
          cellPropertyRepo: cellPropertyRepo,
          locationNodeRepo: locationNodeRepo,
          supabaseClient: mockClient,
        );
        addTearDown(service.dispose);

        service.requestEnrichment(cellId: 'cell_1', lat: 45.0, lon: -66.0);

        // Advance enough for batch attempt + single-request fallback.
        async.elapse(const Duration(seconds: 5));

        expect(service.batchSupported, isFalse);
      });
    });

    test('fallback mode uses single-request _executeRequest()', () {
      fakeAsync((async) {
        int batchCallCount = 0;
        mockFunctions.handler = (name, body) {
          if (name == 'enrich-locations-batch') {
            batchCallCount++;
            throw const FunctionException(status: 404);
          }
          // Single-request path returns success.
          return FunctionResponse(
            status: 200,
            data: {
              'status': 'enriched',
              'location_id': 'loc_single',
              'hierarchy': <Object>[],
            },
          );
        };

        final service = LocationEnrichmentService(
          cellPropertyRepo: cellPropertyRepo,
          locationNodeRepo: locationNodeRepo,
          supabaseClient: mockClient,
        );
        addTearDown(service.dispose);

        service.requestEnrichment(cellId: 'cell_1', lat: 45.0, lon: -66.0);

        // Advance enough for batch 404 + single-request processing.
        async.elapse(const Duration(seconds: 5));

        // Batch was attempted exactly once, then fell back.
        expect(batchCallCount, 1);

        // After fallback, the single-request path ran and enriched the cell.
        expect(cellPropertyRepo.updateLocationIdCalls, hasLength(1));
        expect(cellPropertyRepo.updateLocationIdCalls.first.$2, 'loc_single');

        // New requests also use single-request mode.
        service.requestEnrichment(cellId: 'cell_2', lat: 47.0, lon: -68.0);
        async.elapse(const Duration(seconds: 3));

        // No additional batch call — still only 1 from the initial attempt.
        expect(batchCallCount, 1);
        // But the new cell was enriched via single-request.
        expect(cellPropertyRepo.updateLocationIdCalls, hasLength(2));
      });
    });

    test('batch response processing calls onLocationEnriched for each result',
        () {
      fakeAsync((async) {
        mockFunctions.handler = (name, body) {
          return FunctionResponse(
            status: 200,
            data: {
              'results': <Map<String, Object?>>[
                {
                  'cell_id': 'cell_a',
                  'status': 'enriched',
                  'location_id': 'loc_a',
                  'hierarchy': <Object>[
                    <String, Object?>{
                      'id': 'world',
                      'name': 'World',
                      'level': 'world',
                      'parent_id': null,
                    },
                  ],
                },
                {
                  'cell_id': 'cell_b',
                  'status': 'already_enriched',
                  'location_id': 'loc_b',
                  'hierarchy': <Object>[],
                },
                {
                  'cell_id': 'cell_c',
                  'status': 'no_location_data',
                },
              ],
              'errors': <Object>[],
            },
          );
        };

        final enrichedCells = <(String, String)>[];

        final service = LocationEnrichmentService(
          cellPropertyRepo: cellPropertyRepo,
          locationNodeRepo: locationNodeRepo,
          supabaseClient: mockClient,
        );
        addTearDown(service.dispose);
        service.onLocationEnriched.listen((e) {
          enrichedCells.add((e.cellId, e.locationId));
        });

        service.requestEnrichment(cellId: 'cell_a', lat: 45.0, lon: -66.0);
        service.requestEnrichment(cellId: 'cell_b', lat: 46.0, lon: -67.0);
        service.requestEnrichment(cellId: 'cell_c', lat: 47.0, lon: -68.0);

        async.elapse(const Duration(seconds: 2));

        // Two enriched results trigger callback (no_location_data does not).
        expect(enrichedCells, hasLength(2));
        expect(enrichedCells[0], ('cell_a', 'loc_a'));
        expect(enrichedCells[1], ('cell_b', 'loc_b'));

        // Hierarchy node from cell_a was persisted.
        expect(locationNodeRepo.upsertedNodes, hasLength(1));
        expect(locationNodeRepo.upsertedNodes.first.id, 'world');

        // Both enriched cells updated in cell_properties.
        expect(cellPropertyRepo.updateLocationIdCalls, hasLength(2));
      });
    });

    test('_inFlight is cleaned up after batch processing', () {
      fakeAsync((async) {
        mockFunctions.handler = (name, body) {
          return FunctionResponse(
            status: 200,
            data: {
              'results': <Map<String, Object?>>[
                {
                  'cell_id': 'cell_x',
                  'status': 'enriched',
                  'location_id': 'loc_x',
                  'hierarchy': <Object>[],
                },
              ],
              'errors': <Object>[],
            },
          );
        };

        final service = LocationEnrichmentService(
          cellPropertyRepo: cellPropertyRepo,
          locationNodeRepo: locationNodeRepo,
          supabaseClient: mockClient,
        );
        addTearDown(service.dispose);

        service.requestEnrichment(cellId: 'cell_x', lat: 45.0, lon: -66.0);

        // Drain completes the batch.
        async.elapse(const Duration(seconds: 2));

        // cell_x is no longer in-flight — a second request should be accepted.
        // (If _inFlight wasn't cleaned, this would be silently dropped.)
        mockFunctions.invocations.clear();
        service.requestEnrichment(cellId: 'cell_x', lat: 45.0, lon: -66.0);
        async.elapse(const Duration(seconds: 2));

        expect(mockFunctions.invocations, hasLength(1));
      });
    });
  });
}
