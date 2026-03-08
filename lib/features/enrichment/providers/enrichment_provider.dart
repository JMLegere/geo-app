import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/models/species_enrichment.dart';
import 'package:fog_of_world/core/persistence/enrichment_repository.dart';
import 'package:fog_of_world/core/state/app_database_provider.dart';
import 'package:fog_of_world/features/sync/services/enrichment_service.dart';
import 'package:fog_of_world/features/sync/providers/sync_provider.dart';

final enrichmentRepositoryProvider = Provider<EnrichmentRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return EnrichmentRepository(db);
});

final enrichmentServiceProvider = Provider<EnrichmentService>((ref) {
  final repo = ref.watch(enrichmentRepositoryProvider);
  // Use supabaseClientProvider from sync/ — the single allowed Supabase entry
  // point for features outside of sync/ and supabase_auth_service.dart.
  final client = ref.watch(supabaseClientProvider);
  return EnrichmentService(
    repository: repo,
    supabaseClient: client,
    onEnriched: (_) => ref.invalidate(enrichmentMapProvider),
  );
});

/// Loads all cached enrichments from SQLite.
///
/// Invalidated by [EnrichmentService.onEnriched] after each successful
/// enrichment, which causes [speciesServiceProvider] to rebuild with the
/// new data.
final enrichmentMapProvider =
    FutureProvider<Map<String, SpeciesEnrichment>>((ref) async {
  final repo = ref.watch(enrichmentRepositoryProvider);
  final all = await repo.getAllEnrichments();
  return {for (final e in all) e.definitionId: e};
});
