import 'package:earth_nova/features/home/domain/entities/home.dart';

/// Read-only port for the authenticated Player's server-owned Home identity.
abstract interface class HomeRepository {
  Future<Home> readHome(
    String playerId, {
    required String traceId,
  });
}

/// Safe repository failure for Home reads. It exposes no transport or database
/// detail to presentation code or telemetry.
final class HomeFailure implements Exception {
  const HomeFailure._(this.kind);

  const HomeFailure.ownerMismatch() : this._(HomeFailureKind.ownerMismatch);
  const HomeFailure.malformedPayload()
      : this._(HomeFailureKind.malformedPayload);
  const HomeFailure.unavailable() : this._(HomeFailureKind.unavailable);

  final HomeFailureKind kind;

  @override
  String toString() => 'Home request failed (${kind.name}).';
}

enum HomeFailureKind {
  ownerMismatch,
  malformedPayload,
  unavailable,
}
