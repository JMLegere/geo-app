import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';

enum PendingCommandKind {
  identifyItem('identify_item');

  const PendingCommandKind(this.wireName);
  final String wireName;

  static PendingCommandKind parse(String value) => switch (value) {
    'identify_item' => PendingCommandKind.identifyItem,
    _ => throw FormatException('Unsupported pending command kind.'),
  };
}

enum PendingCommandState {
  pending('pending'),
  dispatching('dispatching'),
  retryWait('retry_wait'),
  pausedAuth('paused_auth'),
  confirmed('confirmed'),
  terminal('terminal');

  const PendingCommandState(this.wireName);
  final String wireName;

  static PendingCommandState parse(String value) => switch (value) {
    'pending' => PendingCommandState.pending,
    'dispatching' => PendingCommandState.dispatching,
    'retry_wait' => PendingCommandState.retryWait,
    'paused_auth' => PendingCommandState.pausedAuth,
    'confirmed' => PendingCommandState.confirmed,
    'terminal' => PendingCommandState.terminal,
    _ => throw FormatException('Unsupported pending command state.'),
  };
}

enum SyncFailureKind {
  network,
  rateLimited,
  transientServer,
  auth,
  validation,
  permission,
  ownership,
  contract,
  unknown,
}

final class IdentificationCommandPayload {
  const IdentificationCommandPayload({required this.plan});

  static const currentVersion = 1;
  final ItemIdentificationPlan plan;
}

final class PendingCommand {
  factory PendingCommand({
    required int schemaVersion,
    required String commandId,
    required String idempotencyKey,
    required PendingCommandKind kind,
    required int payloadVersion,
    required IdentificationCommandPayload payload,
    required String environment,
    required String playerId,
    required DateTime enqueuedAt,
    int attemptCount = 0,
    DateTime? nextEligibleAttemptAt,
    SyncFailureKind? lastFailure,
    required PendingCommandState state,
  }) {
    if (schemaVersion != currentSchemaVersion) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (payloadVersion != IdentificationCommandPayload.currentVersion) {
      throw ArgumentError.value(payloadVersion, 'payloadVersion');
    }
    final canonicalCommandId = _nonBlank(commandId, 'commandId');
    final canonicalIdempotencyKey = _nonBlank(
      idempotencyKey,
      'idempotencyKey',
    );
    final canonicalPlayerId = _nonBlank(playerId, 'playerId');
    if (environment != 'local' && environment != 'prod') {
      throw ArgumentError.value(environment, 'environment');
    }
    if (!enqueuedAt.isUtc) {
      throw ArgumentError.value(enqueuedAt, 'enqueuedAt', 'must be UTC');
    }
    if (attemptCount < 0) {
      throw ArgumentError.value(attemptCount, 'attemptCount');
    }
    if (nextEligibleAttemptAt != null && !nextEligibleAttemptAt.isUtc) {
      throw ArgumentError.value(
        nextEligibleAttemptAt,
        'nextEligibleAttemptAt',
        'must be UTC',
      );
    }
    if (nextEligibleAttemptAt != null &&
        nextEligibleAttemptAt.isBefore(enqueuedAt)) {
      throw ArgumentError.value(
        nextEligibleAttemptAt,
        'nextEligibleAttemptAt',
        'must not predate enqueue time',
      );
    }
    if ((state == PendingCommandState.retryWait) !=
        (nextEligibleAttemptAt != null)) {
      throw ArgumentError(
        'retry_wait requires one UTC next eligible attempt and other states do not',
      );
    }
    if (payload.plan.item.playerId != canonicalPlayerId) {
      throw ArgumentError.value(playerId, 'playerId', 'must own the plan');
    }
    return PendingCommand._(
      schemaVersion: schemaVersion,
      commandId: canonicalCommandId,
      idempotencyKey: canonicalIdempotencyKey,
      kind: kind,
      payloadVersion: payloadVersion,
      payload: payload,
      environment: environment,
      playerId: canonicalPlayerId,
      enqueuedAt: enqueuedAt,
      attemptCount: attemptCount,
      nextEligibleAttemptAt: nextEligibleAttemptAt,
      lastFailure: lastFailure,
      state: state,
    );
  }

  const PendingCommand._({
    required this.schemaVersion,
    required this.commandId,
    required this.idempotencyKey,
    required this.kind,
    required this.payloadVersion,
    required this.payload,
    required this.environment,
    required this.playerId,
    required this.enqueuedAt,
    required this.attemptCount,
    required this.nextEligibleAttemptAt,
    required this.lastFailure,
    required this.state,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String commandId;
  final String idempotencyKey;
  final PendingCommandKind kind;
  final int payloadVersion;
  final IdentificationCommandPayload payload;
  final String environment;
  final String playerId;
  final DateTime enqueuedAt;
  final int attemptCount;
  final DateTime? nextEligibleAttemptAt;
  final SyncFailureKind? lastFailure;
  final PendingCommandState state;

  PendingCommand copyWith({
    PendingCommandState? state,
    int? attemptCount,
    DateTime? nextEligibleAttemptAt,
    bool clearNextEligibleAttemptAt = false,
    SyncFailureKind? lastFailure,
    bool clearLastFailure = false,
  }) =>
      PendingCommand(
        schemaVersion: schemaVersion,
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        kind: kind,
        payloadVersion: payloadVersion,
        payload: payload,
        environment: environment,
        playerId: playerId,
        enqueuedAt: enqueuedAt,
        attemptCount: attemptCount ?? this.attemptCount,
        nextEligibleAttemptAt: clearNextEligibleAttemptAt
            ? null
            : nextEligibleAttemptAt ?? this.nextEligibleAttemptAt,
        lastFailure:
            clearLastFailure ? null : lastFailure ?? this.lastFailure,
        state: state ?? this.state,
      );

  PendingCommand recoveredAfterRestart() =>
      state == PendingCommandState.dispatching
          ? copyWith(
              state: PendingCommandState.pending,
              clearNextEligibleAttemptAt: true,
            )
          : this;
}

String _nonBlank(String value, String name) {
  final canonical = value.trim();
  if (canonical.isEmpty) throw ArgumentError.value(value, name);
  return canonical;
}
