import 'package:fog_of_world/core/database/app_database.dart';
import 'package:fog_of_world/core/models/species_enrichment.dart';

class EnrichmentRepository {
  EnrichmentRepository(this._db);

  final AppDatabase _db;

  Future<SpeciesEnrichment?> getEnrichment(String definitionId) async {
    final row = await _db.getEnrichment(definitionId);
    return row == null ? null : SpeciesEnrichment.fromDrift(row);
  }

  Future<List<SpeciesEnrichment>> getAllEnrichments() async {
    final rows = await _db.getAllEnrichments();
    return rows.map(SpeciesEnrichment.fromDrift).toList();
  }

  Future<void> upsertEnrichment(SpeciesEnrichment enrichment) async {
    await _db.upsertEnrichment(enrichment.toDriftRow());
  }

  Future<void> upsertAll(List<SpeciesEnrichment> enrichments) async {
    for (final e in enrichments) {
      await _db.upsertEnrichment(e.toDriftRow());
    }
  }

  Future<List<SpeciesEnrichment>> getEnrichmentsSince(DateTime since) async {
    final rows = await _db.getEnrichmentsSince(since);
    return rows.map(SpeciesEnrichment.fromDrift).toList();
  }
}
