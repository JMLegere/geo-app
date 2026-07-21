import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';

/// Records a physical Venue Visit after a future trigger adapter has supplied
/// an exact persisted Cell Visit and authored Venue Version evidence.
///
/// This use case intentionally owns no GPS, geofence, map-entry, Item, rarity,
/// or Reveal Outcome policy. Those concerns are either already committed before
/// this command or remain deliberately open.
final class RecordVenueVisit
    extends ObservableUseCase<RecordVenueVisitCommand, VenueVisitResult> {
  const RecordVenueVisit(this._repository, this._observability);

  final LivingWorldCommandRepository _repository;
  final ObservabilityService _observability;

  @override
  ObservabilityService get obs => _observability;

  @override
  String get operationName => 'record_venue_visit';

  @override
  Future<VenueVisitResult> execute(
    RecordVenueVisitCommand input,
    String traceId,
  ) =>
      _repository.recordVenueVisit(input, traceId: traceId);

  @override
  Object summarizeInput(RecordVenueVisitCommand input) => {
        'cell_visit_id': input.cellVisit.id,
        'venue_id': input.venueId.value,
        'venue_version_id': input.venueVersion.versionId.value,
      };

  @override
  Object summarizeOutput(VenueVisitResult output) => {
        'venue_visit_id': output.visit.id.value,
        'idempotent_retry': output.isIdempotentRetry,
        'introduced_villager_count': output.introducedVillagers.length,
      };
}
