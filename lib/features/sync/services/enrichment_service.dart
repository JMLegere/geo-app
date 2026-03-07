import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fog_of_world/core/models/species_enrichment.dart';
import 'package:fog_of_world/core/persistence/enrichment_repository.dart';

class EnrichmentService {
  EnrichmentService({
    required this.repository,
    this.supabaseClient,
  });

  final EnrichmentRepository repository;
  final SupabaseClient? supabaseClient;

  Future<void> requestEnrichment({
    required String definitionId,
    required String scientificName,
    required String commonName,
    required String taxonomicClass,
  }) async {
    final client = supabaseClient;
    if (client == null) return;

    try {
      final response = await client.functions.invoke(
        'enrich-species',
        body: {
          'definition_id': definitionId,
          'scientific_name': scientificName,
          'common_name': commonName,
          'taxonomic_class': taxonomicClass,
        },
      );

      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (!data.containsKey('error')) {
          final enrichment = SpeciesEnrichment.fromJson(data);
          await repository.upsertEnrichment(enrichment);
        } else {
          debugPrint('[EnrichmentService] enrichment error for $definitionId: ${data['error']}');
        }
      }
    } catch (e) {
      debugPrint('[EnrichmentService] requestEnrichment failed for $definitionId: $e');
    }
  }

  Future<int> syncEnrichments({DateTime? since}) async {
    final client = supabaseClient;
    if (client == null) return 0;

    try {
      var query = client.from('species_enrichment').select();
      if (since != null) {
        query = query.gte('enriched_at', since.toIso8601String());
      }

      final response = await query;
      final rows = List<Map<String, dynamic>>.from(response as List);
      final enrichments = rows
          .map((row) {
            try {
              return SpeciesEnrichment.fromJson(row);
            } catch (e) {
              debugPrint('[EnrichmentService] failed to parse enrichment row: $e');
              return null;
            }
          })
          .whereType<SpeciesEnrichment>()
          .toList();

      await repository.upsertAll(enrichments);
      return enrichments.length;
    } catch (e) {
      debugPrint('[EnrichmentService] syncEnrichments failed: $e');
      return 0;
    }
  }

  Future<Map<String, SpeciesEnrichment>> getEnrichmentMap() async {
    final all = await repository.getAllEnrichments();
    return {for (final e in all) e.definitionId: e};
  }
}
