import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';

/// Read boundary for the pure player-scoped Town projection.
abstract interface class LivingWorldReadRepository {
  /// Reads Town without revealing content, recording a Visit, or mutating state.
  Future<TownProjection> readTown(
    String playerId, {
    required String traceId,
  });
}

/// Command boundary for atomic Living World mutations.
abstract interface class LivingWorldCommandRepository {
  /// Records a Venue Visit from exact persisted Visit and authored Version
  /// evidence. The adapter owns authorization, locking, idempotency, and the
  /// all-or-none introduction transaction.
  Future<VenueVisitResult> recordVenueVisit(
    RecordVenueVisitCommand command, {
    required String traceId,
  });
}

/// Typed Living World read and command ports.
///
/// Flutter callers receive no table-write surface: adapters must use the
/// authoritative command transaction for Visits and introductions.
abstract interface class LivingWorldRepository
    implements LivingWorldReadRepository, LivingWorldCommandRepository {}

/// A deliberately safe failure that repository adapters may expose to use
/// cases, telemetry, and UI without leaking database details.
final class LivingWorldFailure implements Exception {
  const LivingWorldFailure._(this.kind);

  const LivingWorldFailure.unknownVenue()
      : this._(LivingWorldFailureKind.unknownVenue);
  const LivingWorldFailure.venueNotKnown()
      : this._(LivingWorldFailureKind.venueNotKnown);
  const LivingWorldFailure.cellVisitNotOwned()
      : this._(LivingWorldFailureKind.cellVisitNotOwned);
  const LivingWorldFailure.cellVisitAnchorMismatch()
      : this._(LivingWorldFailureKind.cellVisitAnchorMismatch);
  const LivingWorldFailure.versionMismatch()
      : this._(LivingWorldFailureKind.versionMismatch);
  const LivingWorldFailure.unavailable()
      : this._(LivingWorldFailureKind.unavailable);
  const LivingWorldFailure.malformedPayload()
      : this._(LivingWorldFailureKind.malformedPayload);

  final LivingWorldFailureKind kind;

  @override
  String toString() => 'Living World request failed (${kind.name}).';
}

enum LivingWorldFailureKind {
  unknownVenue,
  venueNotKnown,
  cellVisitNotOwned,
  cellVisitAnchorMismatch,
  versionMismatch,
  unavailable,
  malformedPayload,
}
