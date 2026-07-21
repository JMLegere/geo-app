import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';

/// Deterministic in-memory repository for focused Living World tests and
/// offline previews. It exposes only the same read/command port as Supabase.
typedef MockVenueVisitHandler = Future<VenueVisitResult> Function(
  RecordVenueVisitCommand command,
);

final class MockLivingWorldRepository implements LivingWorldRepository {
  MockLivingWorldRepository({
    TownProjection? town,
    MockVenueVisitHandler? recordVenueVisit,
  })  : _town = town,
        _recordVenueVisit = recordVenueVisit;

  TownProjection? _town;
  final MockVenueVisitHandler? _recordVenueVisit;
  final List<RecordVenueVisitCommand> recordedVenueVisits = [];
  int townReadCount = 0;

  /// Replaces the durable in-memory projection used by subsequent reads.
  set town(TownProjection value) => _town = value;

  @override
  Future<TownProjection> readTown(
    String playerId, {
    required String traceId,
  }) async {
    townReadCount += 1;
    final town = _town;
    if (town == null || town.playerId != playerId) {
      throw const LivingWorldFailure.unavailable();
    }
    return town;
  }

  @override
  Future<VenueVisitResult> recordVenueVisit(
    RecordVenueVisitCommand command, {
    required String traceId,
  }) async {
    recordedVenueVisits.add(command);
    final handler = _recordVenueVisit;
    if (handler == null) throw const LivingWorldFailure.unavailable();
    final result = await handler(command);
    if (result.visit.playerId != command.playerId ||
        result.visit.venueId != command.venueId ||
        result.visit.venueVersion != command.venueVersion ||
        result.visit.cellVisit.id != command.cellVisit.id ||
        result.visit.cellVisit.cellId != command.cellVisit.cellId) {
      throw const LivingWorldFailure.malformedPayload();
    }
    _town = result.town;
    return result;
  }
}
