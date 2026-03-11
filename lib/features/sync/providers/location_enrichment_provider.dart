import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/cell_property_repository_provider.dart';
import 'package:earth_nova/core/state/location_node_repository_provider.dart';
import 'package:earth_nova/features/sync/providers/sync_provider.dart';
import 'package:earth_nova/features/sync/services/location_enrichment_service.dart';

/// Singleton [LocationEnrichmentService] for async location hierarchy
/// enrichment via the `enrich-location` Supabase Edge Function.
///
/// Wired into [gameCoordinatorProvider] — when a cell is resolved with no
/// `locationId`, the coordinator fires `requestEnrichment()` on this service.
/// The service rate-limits to 1 req/1.2s (Nominatim policy) and caches
/// results in local SQLite + Supabase.
final locationEnrichmentServiceProvider =
    Provider<LocationEnrichmentService>((ref) {
  final cellPropertyRepo = ref.watch(cellPropertyRepositoryProvider);
  final locationNodeRepo = ref.watch(locationNodeRepositoryProvider);
  final client = ref.watch(supabaseClientProvider);

  final service = LocationEnrichmentService(
    cellPropertyRepo: cellPropertyRepo,
    locationNodeRepo: locationNodeRepo,
    supabaseClient: client,
  );

  ref.onDispose(service.dispose);

  return service;
});
