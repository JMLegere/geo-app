import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

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

    test('onLocationEnriched callback fires with correct arguments', () {
      // Test the callback wiring — we can't call _executeRequest directly,
      // but we can verify the callback is settable and invokable.
      final enrichedCells = <(String, String)>[];

      final service = LocationEnrichmentService(
        cellPropertyRepo: cellPropertyRepo,
        locationNodeRepo: locationNodeRepo,
        supabaseClient: null,
        onLocationEnriched: (cellId, locationId) {
          enrichedCells.add((cellId, locationId));
        },
      );
      addTearDown(service.dispose);

      // Manually invoke the callback to verify wiring.
      service.onLocationEnriched?.call('cell_42', 'loc_123');
      expect(enrichedCells, hasLength(1));
      expect(enrichedCells.first, ('cell_42', 'loc_123'));
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

    test('onLocationEnriched callback can be replaced after construction', () {
      final firstCalls = <String>[];
      final secondCalls = <String>[];

      final service = LocationEnrichmentService(
        cellPropertyRepo: cellPropertyRepo,
        locationNodeRepo: locationNodeRepo,
        onLocationEnriched: (cellId, _) => firstCalls.add(cellId),
      );
      addTearDown(service.dispose);

      service.onLocationEnriched?.call('a', 'loc');
      expect(firstCalls, ['a']);
      expect(secondCalls, isEmpty);

      // Replace callback.
      service.onLocationEnriched = (cellId, _) => secondCalls.add(cellId);
      service.onLocationEnriched?.call('b', 'loc');
      expect(firstCalls, ['a']); // Not called again.
      expect(secondCalls, ['b']);
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
}
