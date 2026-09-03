import 'dart:async';

import 'package:earth_nova/app/sync/application/sync_retry_policy.dart';
import 'package:earth_nova/app/sync/domain/pending_command.dart';
import 'package:earth_nova/app/sync/domain/pending_command_store.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/identification/domain/repositories/identification_repository.dart';

typedef SyncLogEvent = void Function(
  String event,
  String category, {
  Map<String, Object?>? data,
});
typedef RetryScheduler = Timer Function(
  Duration delay,
  void Function() callback,
);
typedef ApplyIdentificationResult = FutureOr<void> Function(
  ItemIdentificationResult result,
);

final class IdentificationSyncPending implements Exception {
  const IdentificationSyncPending();
}

final class IdentificationSyncTerminal implements Exception {
  const IdentificationSyncTerminal();
}

/// Durable, serialized application boundary for the one approved replay-safe
/// command: committing an already prepared Identification plan.
final class IdentificationSyncService {
  IdentificationSyncService({
    required String environment,
    required PendingCommandStore store,
    required IdentificationRepository repository,
    required SyncRetryPolicy retryPolicy,
    required DateTime Function() now,
    required String Function() commandId,
    required double Function() jitterUnit,
    required SyncLogEvent logEvent,
    ApplyIdentificationResult? backgroundApplyCanonicalResult,
    RetryScheduler? scheduleRetry,
  }) : _environment = _validatedEnvironment(environment),
       _store = store,
       _repository = repository,
       _retryPolicy = retryPolicy,
       _now = now,
       _commandId = commandId,
       _jitterUnit = jitterUnit,
       _logEvent = logEvent,
       _backgroundApplyCanonicalResult = backgroundApplyCanonicalResult,
       _scheduleRetry = scheduleRetry ??
           ((delay, callback) => Timer(delay, callback));

  static const _category = 'sync';

  final String _environment;
  final PendingCommandStore _store;
  final IdentificationRepository _repository;
  final SyncRetryPolicy _retryPolicy;
  final DateTime Function() _now;
  final String Function() _commandId;
  final double Function() _jitterUnit;
  final SyncLogEvent _logEvent;
  final ApplyIdentificationResult? _backgroundApplyCanonicalResult;
  final RetryScheduler _scheduleRetry;
  final Map<String, Timer> _retryTimers = {};
  Future<void> _serial = Future.value();
  bool _disposed = false;

  Future<ItemIdentificationResult> commit(
    ItemIdentificationPlan plan, {
    required String playerId,
    required ApplyIdentificationResult applyCanonicalResult,
    String? traceId,
  }) =>
      _exclusive(() async {
        _validatePlayer(playerId, plan);
        final commands = await _load(playerId);
        final idempotencyKey = 'identify:${plan.item.id.value}';
        final matches = commands.where(
          (command) => command.idempotencyKey == idempotencyKey,
        );
        PendingCommand command;
        if (matches.isNotEmpty) {
          command = matches.single;
          if (command.payload.plan != plan) {
            _terminalEvent(command, reason: 'payload_mismatch');
            throw const IdentificationSyncTerminal();
          }
        } else {
          command = PendingCommand(
            schemaVersion: PendingCommand.currentSchemaVersion,
            commandId: _commandId(),
            idempotencyKey: idempotencyKey,
            kind: PendingCommandKind.identifyItem,
            payloadVersion: IdentificationCommandPayload.currentVersion,
            payload: IdentificationCommandPayload(plan: plan),
            environment: _environment,
            playerId: playerId,
            enqueuedAt: _utcNow(),
            state: PendingCommandState.pending,
          );
          try {
            await _store.enqueue(command);
          } on QueueBoundFailure {
            _event('sync.queue.bound_exceeded');
            _event('sync.command.enqueue_rejected');
            rethrow;
          } catch (_) {
            _event('sync.command.enqueue_rejected');
            rethrow;
          }
          _event('sync.command.enqueued');
        }
        return _dispatch(
          command,
          applyCanonicalResult: applyCanonicalResult,
          traceId: traceId,
          recovery: false,
        );
      });

  Future<List<ItemIdentificationResult>> recover({
    required String playerId,
    required ApplyIdentificationResult applyCanonicalResult,
    bool forceEligible = false,
    String? traceId,
  }) =>
      _exclusive(() async {
        final commands = await _load(playerId);
        final results = <ItemIdentificationResult>[];
        for (final command in commands) {
          if (command.environment != _environment ||
              command.playerId != playerId ||
              command.payload.plan.item.playerId != playerId) {
            _terminalEvent(command, reason: 'owner_mismatch');
            throw const IdentificationSyncTerminal();
          }
          if (command.state == PendingCommandState.terminal ||
              command.state == PendingCommandState.confirmed ||
              command.state == PendingCommandState.pausedAuth) {
            continue;
          }
          final eligibleAt = command.nextEligibleAttemptAt;
          if (!forceEligible &&
              eligibleAt != null &&
              eligibleAt.isAfter(_utcNow())) {
            _schedule(
              command,
              eligibleAt.difference(_utcNow()),
              playerId: playerId,
              applyCanonicalResult: applyCanonicalResult,
              traceId: traceId,
            );
            continue;
          }
          try {
            results.add(
              await _dispatch(
                command.copyWith(
                  state: PendingCommandState.pending,
                  clearNextEligibleAttemptAt: true,
                ),
                applyCanonicalResult: applyCanonicalResult,
                traceId: traceId,
                recovery: true,
              ),
            );
          } on IdentificationSyncPending {
            // The exact record remains durable and its timer is active.
          }
        }
        return List.unmodifiable(results);
      });

  Future<void> resumeAfterAuthentication({
    required String playerId,
    required ApplyIdentificationResult applyCanonicalResult,
    String? traceId,
  }) async {
    await _exclusive(() async {
      final commands = await _load(playerId);
      for (final command in commands.where(
        (entry) => entry.state == PendingCommandState.pausedAuth,
      )) {
        final pending = command.copyWith(
          state: PendingCommandState.pending,
          clearLastFailure: true,
        );
        await _store.replace(pending);
      }
    });
    await recover(
      playerId: playerId,
      applyCanonicalResult: applyCanonicalResult,
      traceId: traceId,
    );
  }

  Future<void> purge({required String playerId}) => _exclusive(() async {
    _cancelTimers();
    try {
      await _store.purge(environment: _environment, playerId: playerId);
      _event('sync.queue.purged');
    } catch (_) {
      _event('sync.queue.purge_failed');
      rethrow;
    }
  });

  void dispose() {
    _disposed = true;
    _cancelTimers();
  }

  Future<ItemIdentificationResult> _dispatch(
    PendingCommand command, {
    required ApplyIdentificationResult applyCanonicalResult,
    required String? traceId,
    required bool recovery,
  }) async {
    final dispatching = command.copyWith(
      state: PendingCommandState.dispatching,
      attemptCount: command.attemptCount + 1,
      clearNextEligibleAttemptAt: true,
    );
    await _store.replace(dispatching);
    _event(
      'sync.command.dispatch_started',
      data: {'attempt_count': dispatching.attemptCount},
    );
    try {
      final result = await _repository.commit(
        dispatching.payload.plan,
        traceId: traceId,
      );
      await applyCanonicalResult(result);
      final confirmed = dispatching.copyWith(
        state: PendingCommandState.confirmed,
        clearLastFailure: true,
      );
      await _store.replace(confirmed);
      await _store.remove(confirmed);
      _retryTimers.remove(command.commandId)?.cancel();
      _event(
        'sync.command.confirmed',
        data: {'attempt_count': dispatching.attemptCount},
      );
      if (recovery || dispatching.attemptCount > 1) {
        _event('sync.recovery.completed');
      }
      return result;
    } catch (error) {
      final disposition = _retryPolicy.classify(error);
      switch (disposition) {
        case SyncFailureDisposition.retryable:
          final delay = _retryPolicy.delayForAttempt(
            dispatching.attemptCount,
            jitterUnit: _jitterUnit(),
          );
          final retrying = dispatching.copyWith(
            state: PendingCommandState.retryWait,
            nextEligibleAttemptAt: _utcNow().add(delay),
            lastFailure: _failureKind(error),
          );
          await _store.replace(retrying);
          _event(
            'sync.command.retry_scheduled',
            data: {
              'attempt_count': retrying.attemptCount,
              'delay_ms': delay.inMilliseconds,
            },
          );
          _schedule(
            retrying,
            delay,
            playerId: retrying.playerId,
            applyCanonicalResult: applyCanonicalResult,
            traceId: traceId,
          );
          throw const IdentificationSyncPending();
        case SyncFailureDisposition.pauseForAuth:
          final paused = dispatching.copyWith(
            state: PendingCommandState.pausedAuth,
            lastFailure: SyncFailureKind.auth,
          );
          await _store.replace(paused);
          _event('sync.command.auth_paused');
          throw const IdentificationSyncPending();
        case SyncFailureDisposition.terminal:
          final terminal = dispatching.copyWith(
            state: PendingCommandState.terminal,
            lastFailure: _failureKind(error),
          );
          await _store.replace(terminal);
          _terminalEvent(terminal, reason: 'permanent_failure');
          throw const IdentificationSyncTerminal();
      }
    }
  }

  Future<List<PendingCommand>> _load(String playerId) async {
    _event('sync.queue.load_started');
    try {
      final commands = await _store.load(
        environment: _environment,
        playerId: playerId,
        now: _utcNow(),
      );
      _event(
        'sync.queue.load_completed',
        data: {'pending_count': commands.length},
      );
      return commands;
    } on QueueCorruptFailure {
      _event('sync.queue.corrupt_removed');
      _event('sync.queue.load_failed');
      rethrow;
    } on QueueBoundFailure {
      _event('sync.queue.bound_exceeded');
      _event('sync.queue.load_failed');
      rethrow;
    } catch (_) {
      _event('sync.queue.load_failed');
      rethrow;
    }
  }

  void _schedule(
    PendingCommand command,
    Duration delay, {
    required String playerId,
    required ApplyIdentificationResult applyCanonicalResult,
    required String? traceId,
  }) {
    _retryTimers.remove(command.commandId)?.cancel();
    if (_disposed) return;
    _retryTimers[command.commandId] = _scheduleRetry(delay, () {
      if (_disposed) return;
      final backgroundApply =
          _backgroundApplyCanonicalResult ?? applyCanonicalResult;
      unawaited(
        recover(
          playerId: playerId,
          applyCanonicalResult: backgroundApply,
          forceEligible: true,
          traceId: traceId,
        ).catchError((Object _) => const <ItemIdentificationResult>[]),
      );
    });
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _serial = _serial.then((_) async {
      if (_disposed) {
        completer.completeError(StateError('Identification sync is disposed.'));
        return;
      }
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  DateTime _utcNow() {
    final value = _now();
    if (!value.isUtc) throw StateError('Sync clock must return UTC.');
    return value;
  }

  void _validatePlayer(String playerId, ItemIdentificationPlan plan) {
    if (playerId.trim().isEmpty || plan.item.playerId != playerId) {
      throw const IdentificationSyncTerminal();
    }
  }

  void _terminalEvent(PendingCommand command, {required String reason}) {
    _event(
      'sync.command.terminal',
      data: {
        'attempt_count': command.attemptCount,
        'reason': reason,
      },
    );
  }

  void _event(String event, {Map<String, Object?>? data}) {
    _logEvent(
      event,
      _category,
      data: {
        'environment': _environment,
        'command_kind': PendingCommandKind.identifyItem.wireName,
        ...?data,
      },
    );
  }

  void _cancelTimers() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
  }
}

String _validatedEnvironment(String environment) {
  if (environment != 'local' && environment != 'prod') {
    throw ArgumentError.value(environment, 'environment');
  }
  return environment;
}

SyncFailureKind _failureKind(Object error) {
  if (error is! IdentificationCommitFailure) return SyncFailureKind.unknown;
  return switch (error.kind) {
    IdentificationFailureKind.network => SyncFailureKind.network,
    IdentificationFailureKind.rateLimited => SyncFailureKind.rateLimited,
    IdentificationFailureKind.transientServer => SyncFailureKind.transientServer,
    IdentificationFailureKind.auth => SyncFailureKind.auth,
    IdentificationFailureKind.validation => SyncFailureKind.validation,
    IdentificationFailureKind.permission => SyncFailureKind.permission,
    IdentificationFailureKind.ownership => SyncFailureKind.ownership,
    IdentificationFailureKind.contract => SyncFailureKind.contract,
    IdentificationFailureKind.unknown => SyncFailureKind.unknown,
  };
}
