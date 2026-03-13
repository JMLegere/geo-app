import 'package:flutter_test/flutter_test.dart';
import 'package:functions_client/functions_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/models/species_enrichment.dart';
import 'package:earth_nova/core/persistence/enrichment_repository.dart';
import 'package:earth_nova/features/sync/services/enrichment_service.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockEnrichmentRepository implements EnrichmentRepository {
  final List<SpeciesEnrichment> upserted = [];

  @override
  Future<void> upsertEnrichment(SpeciesEnrichment enrichment) async {
    upserted.add(enrichment);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'MockEnrichmentRepository.${invocation.memberName}');
}

/// Minimal mock of [FunctionsClient] that records invoke calls and returns
/// configurable responses.
class MockFunctionsClient implements FunctionsClient {
  final List<({String functionName, Map<String, dynamic>? body})> invocations =
      [];

  /// Set this to control the response for each invoke call.
  /// If it throws a [FunctionException], that exception is re-thrown.
  FunctionResponse Function(String functionName, Map<String, dynamic>? body)?
      onInvoke;

  @override
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, String>? headers,
    Object? body,
    Iterable<dynamic>? files,
    Map<String, dynamic>? queryParameters,
    HttpMethod method = HttpMethod.post,
    String? region,
  }) async {
    final bodyMap = body as Map<String, dynamic>?;
    invocations.add((functionName: functionName, body: bodyMap));
    if (onInvoke != null) {
      return onInvoke!(functionName, bodyMap);
    }
    return FunctionResponse(data: null, status: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('MockFunctionsClient.${invocation.memberName}');
}

/// Minimal mock of [GoTrueClient] that provides a null session (no auth).
class MockGoTrueClient implements GoTrueClient {
  @override
  Session? get currentSession => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('MockGoTrueClient.${invocation.memberName}');
}

/// Minimal mock of [SupabaseClient] that wires mock functions + auth.
class MockSupabaseClient implements SupabaseClient {
  MockSupabaseClient({required this.mockFunctions, MockGoTrueClient? mockAuth})
      : mockAuth = mockAuth ?? MockGoTrueClient();

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
// Helpers
// =============================================================================

/// Creates a valid enrichment JSON map for a given definition ID.
Map<String, dynamic> makeEnrichmentJson({
  required String definitionId,
  String animalClass = 'carnivore',
  String foodPreference = 'critter',
  String climate = 'temperate',
  int brawn = 40,
  int wit = 20,
  int speed = 30,
  String size = 'medium',
}) =>
    {
      'definition_id': definitionId,
      'animal_class': animalClass,
      'food_preference': foodPreference,
      'climate': climate,
      'brawn': brawn,
      'wit': wit,
      'speed': speed,
      'size': size,
      'art_url': null,
      'enriched_at': DateTime.now().toIso8601String(),
    };

/// Creates a batch response with results and optional errors.
Map<String, dynamic> makeBatchResponse({
  List<Map<String, dynamic>> results = const [],
  List<Map<String, dynamic>> errors = const [],
}) =>
    {
      'results': results,
      'errors': errors,
    };

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockEnrichmentRepository repository;
  late MockFunctionsClient mockFunctions;
  late MockSupabaseClient mockClient;

  setUp(() {
    repository = MockEnrichmentRepository();
    mockFunctions = MockFunctionsClient();
    mockClient = MockSupabaseClient(mockFunctions: mockFunctions);
  });

  group('EnrichmentService', () {
    test('requestEnrichment is no-op when supabaseClient is null', () async {
      final service = EnrichmentService(
        repository: repository,
        supabaseClient: null,
      );
      addTearDown(service.dispose);

      await service.requestEnrichment(
        definitionId: 'sp_1',
        scientificName: 'Canis lupus',
        commonName: 'Gray Wolf',
        taxonomicClass: 'MAMMALIA',
      );

      // Nothing queued, no calls.
      expect(mockFunctions.invocations, isEmpty);
      expect(repository.upserted, isEmpty);
    });

    test('deduplicates concurrent requests for same definitionId', () async {
      mockFunctions.onInvoke = (functionName, body) {
        final species = body!['species'] as List;
        return FunctionResponse(
          data: makeBatchResponse(
            results: (species as List<Map<String, dynamic>>)
                .map(
                    (s) => makeEnrichmentJson(definitionId: s['definition_id']))
                .toList(),
          ),
          status: 200,
        );
      };

      final service = EnrichmentService(
        repository: repository,
        supabaseClient: mockClient,
        baseDelayMs: 0,
      );
      addTearDown(service.dispose);

      // First request enqueues.
      await service.requestEnrichment(
        definitionId: 'sp_1',
        scientificName: 'Canis lupus',
        commonName: 'Gray Wolf',
        taxonomicClass: 'MAMMALIA',
      );

      // Second request for same ID is silently dropped (still in-flight).
      await service.requestEnrichment(
        definitionId: 'sp_1',
        scientificName: 'Canis lupus',
        commonName: 'Gray Wolf',
        taxonomicClass: 'MAMMALIA',
      );

      // Give the drain timer a chance to fire.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Only one invocation — the duplicate was dropped.
      expect(mockFunctions.invocations, hasLength(1));

      // Only one species in the batch payload.
      final species = mockFunctions.invocations.first.body!['species'] as List;
      expect(species, hasLength(1));
    });

    test('batch mode sends single batch request for multiple species',
        () async {
      mockFunctions.onInvoke = (functionName, body) {
        expect(functionName, 'enrich-species-batch');
        final species = body!['species'] as List;
        return FunctionResponse(
          data: makeBatchResponse(
            results: (species as List<Map<String, dynamic>>)
                .map(
                    (s) => makeEnrichmentJson(definitionId: s['definition_id']))
                .toList(),
          ),
          status: 200,
        );
      };

      final service = EnrichmentService(
        repository: repository,
        supabaseClient: mockClient,
        baseDelayMs: 0,
      );
      addTearDown(service.dispose);

      // Enqueue 3 species.
      await service.requestEnrichment(
        definitionId: 'sp_1',
        scientificName: 'Canis lupus',
        commonName: 'Gray Wolf',
        taxonomicClass: 'MAMMALIA',
      );
      await service.requestEnrichment(
        definitionId: 'sp_2',
        scientificName: 'Vulpes vulpes',
        commonName: 'Red Fox',
        taxonomicClass: 'MAMMALIA',
      );
      await service.requestEnrichment(
        definitionId: 'sp_3',
        scientificName: 'Ursus arctos',
        commonName: 'Brown Bear',
        taxonomicClass: 'MAMMALIA',
      );

      // Wait for drain timer + execution.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should be a single batch call, not 3 individual calls.
      expect(mockFunctions.invocations, hasLength(1));
      expect(
          mockFunctions.invocations.first.functionName, 'enrich-species-batch');

      final species = mockFunctions.invocations.first.body!['species'] as List;
      expect(species, hasLength(3));

      // All 3 upserted.
      expect(repository.upserted, hasLength(3));
    });

    test('priority ordering — high-priority species appear before low-priority',
        () async {
      List<Map<String, dynamic>>? capturedSpecies;

      mockFunctions.onInvoke = (functionName, body) {
        capturedSpecies =
            List<Map<String, dynamic>>.from(body!['species'] as List);
        return FunctionResponse(
          data: makeBatchResponse(
            results: capturedSpecies!
                .map(
                    (s) => makeEnrichmentJson(definitionId: s['definition_id']))
                .toList(),
          ),
          status: 200,
        );
      };

      final service = EnrichmentService(
        repository: repository,
        supabaseClient: mockClient,
        baseDelayMs: 0,
      );
      addTearDown(service.dispose);

      // Enqueue low priority first, then high priority.
      await service.requestEnrichment(
        definitionId: 'sp_low_1',
        scientificName: 'Canis lupus',
        commonName: 'Gray Wolf',
        taxonomicClass: 'MAMMALIA',
        priority: EnrichmentPriority.low,
      );
      await service.requestEnrichment(
        definitionId: 'sp_high_1',
        scientificName: 'Vulpes vulpes',
        commonName: 'Red Fox',
        taxonomicClass: 'MAMMALIA',
        priority: EnrichmentPriority.high,
      );
      await service.requestEnrichment(
        definitionId: 'sp_low_2',
        scientificName: 'Ursus arctos',
        commonName: 'Brown Bear',
        taxonomicClass: 'MAMMALIA',
        priority: EnrichmentPriority.low,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(capturedSpecies, isNotNull);
      // High priority should come first in the batch payload.
      expect(capturedSpecies![0]['definition_id'], 'sp_high_1');
      // Low priority after.
      expect(
          capturedSpecies![1]['definition_id'], isIn(['sp_low_1', 'sp_low_2']));
      expect(
          capturedSpecies![2]['definition_id'], isIn(['sp_low_1', 'sp_low_2']));
    });

    test('404 triggers fallback to single-request mode', () async {
      int callCount = 0;

      mockFunctions.onInvoke = (functionName, body) {
        callCount++;
        if (functionName == 'enrich-species-batch') {
          throw FunctionException(status: 404, details: 'Not found');
        }
        // Single-request fallback — return valid response.
        return FunctionResponse(
          data: makeEnrichmentJson(
              definitionId: body!['definition_id'] as String),
          status: 200,
        );
      };

      final service = EnrichmentService(
        repository: repository,
        supabaseClient: mockClient,
        baseDelayMs: 0,
        minIntervalMs: 0,
      );
      addTearDown(service.dispose);

      expect(service.batchSupported, isTrue);

      await service.requestEnrichment(
        definitionId: 'sp_1',
        scientificName: 'Canis lupus',
        commonName: 'Gray Wolf',
        taxonomicClass: 'MAMMALIA',
      );

      // Wait for batch attempt + fallback drain.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Batch should be disabled after 404.
      expect(service.batchSupported, isFalse);

      // Should have at least 2 calls: 1 batch (404) + 1 single.
      expect(callCount, greaterThanOrEqualTo(2));

      // First call was batch.
      expect(
          mockFunctions.invocations.first.functionName, 'enrich-species-batch');

      // Subsequent calls are single-request.
      final singleCalls = mockFunctions.invocations
          .where((i) => i.functionName == 'enrich-species')
          .toList();
      expect(singleCalls, isNotEmpty);

      // Enrichment was still processed via fallback.
      expect(repository.upserted, hasLength(1));
    });

    test('batch response processing calls both onEnriched and onEnrichedHook',
        () async {
      final onEnrichedCalls = <String>[];
      final onEnrichedHookCalls = <String>[];

      mockFunctions.onInvoke = (functionName, body) {
        final species = body!['species'] as List;
        return FunctionResponse(
          data: makeBatchResponse(
            results: (species as List<Map<String, dynamic>>)
                .map(
                    (s) => makeEnrichmentJson(definitionId: s['definition_id']))
                .toList(),
          ),
          status: 200,
        );
      };

      final service = EnrichmentService(
        repository: repository,
        supabaseClient: mockClient,
        onEnriched: (e) => onEnrichedCalls.add(e.definitionId),
        baseDelayMs: 0,
      );
      service.onEnrichedHook = (e) => onEnrichedHookCalls.add(e.definitionId);
      addTearDown(service.dispose);

      await service.requestEnrichment(
        definitionId: 'sp_1',
        scientificName: 'Canis lupus',
        commonName: 'Gray Wolf',
        taxonomicClass: 'MAMMALIA',
      );
      await service.requestEnrichment(
        definitionId: 'sp_2',
        scientificName: 'Vulpes vulpes',
        commonName: 'Red Fox',
        taxonomicClass: 'MAMMALIA',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Both callbacks should have been called for each result.
      expect(onEnrichedCalls, containsAll(['sp_1', 'sp_2']));
      expect(onEnrichedHookCalls, containsAll(['sp_1', 'sp_2']));
    });

    test('_inFlight is cleaned up after batch processing', () async {
      mockFunctions.onInvoke = (functionName, body) {
        final species = body!['species'] as List;
        return FunctionResponse(
          data: makeBatchResponse(
            results: (species as List<Map<String, dynamic>>)
                .map(
                    (s) => makeEnrichmentJson(definitionId: s['definition_id']))
                .toList(),
          ),
          status: 200,
        );
      };

      final service = EnrichmentService(
        repository: repository,
        supabaseClient: mockClient,
        baseDelayMs: 0,
        minIntervalMs: 0,
      );
      addTearDown(service.dispose);

      await service.requestEnrichment(
        definitionId: 'sp_1',
        scientificName: 'Canis lupus',
        commonName: 'Gray Wolf',
        taxonomicClass: 'MAMMALIA',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // After processing, the same ID should be re-enqueueable (not deduplicated).
      // This proves _inFlight was cleaned up.
      mockFunctions.invocations.clear();
      await service.requestEnrichment(
        definitionId: 'sp_1',
        scientificName: 'Canis lupus',
        commonName: 'Gray Wolf',
        taxonomicClass: 'MAMMALIA',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Second request was accepted and processed (not dedup'd).
      expect(mockFunctions.invocations, hasLength(1));
    });

    test('_inFlight is cleaned up even on batch exception', () async {
      mockFunctions.onInvoke = (functionName, body) {
        throw Exception('Network error');
      };

      final service = EnrichmentService(
        repository: repository,
        supabaseClient: mockClient,
        baseDelayMs: 0,
        minIntervalMs: 0,
      );
      addTearDown(service.dispose);

      await service.requestEnrichment(
        definitionId: 'sp_1',
        scientificName: 'Canis lupus',
        commonName: 'Gray Wolf',
        taxonomicClass: 'MAMMALIA',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // After error, the ID should be re-enqueueable.
      mockFunctions.invocations.clear();
      mockFunctions.onInvoke = (functionName, body) {
        final species = body!['species'] as List;
        return FunctionResponse(
          data: makeBatchResponse(
            results: (species as List<Map<String, dynamic>>)
                .map(
                    (s) => makeEnrichmentJson(definitionId: s['definition_id']))
                .toList(),
          ),
          status: 200,
        );
      };

      await service.requestEnrichment(
        definitionId: 'sp_1',
        scientificName: 'Canis lupus',
        commonName: 'Gray Wolf',
        taxonomicClass: 'MAMMALIA',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(mockFunctions.invocations, hasLength(1));
      expect(repository.upserted, hasLength(1));
    });

    test('dispose cancels drain timer without error', () {
      final service = EnrichmentService(
        repository: repository,
        supabaseClient: null,
      );

      // Should not throw even if no timer was ever created.
      service.dispose();
    });

    test('batchSupported getter reflects internal state', () {
      final service = EnrichmentService(
        repository: repository,
        supabaseClient: null,
      );
      addTearDown(service.dispose);

      expect(service.batchSupported, isTrue);
    });
  });
}
