import 'dart:async';

import 'package:earth_nova/app/sync/application/identification_sync_service.dart';
import 'package:earth_nova/app/sync/application/sync_retry_policy.dart';
import 'package:earth_nova/app/sync/domain/pending_command.dart';
import 'package:earth_nova/app/sync/domain/pending_command_store.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/identification/domain/repositories/identification_repository.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_test_data.dart';

void main() {
  late _MemoryCommandStore store;
  late _RecordingIdentificationRepository repository;
  late List<String> sequence;
  late List<String> events;

  setUp(() {
    sequence = [];
    events = [];
    store = _MemoryCommandStore(sequence);
    repository = _RecordingIdentificationRepository(sequence);
  });

  IdentificationSyncService service({DateTime? now}) =>
      IdentificationSyncService(
        environment: 'local',
        store: store,
        repository: repository,
        retryPolicy: const SyncRetryPolicy(jitterFraction: 0),
        now: () => now ?? DateTime.utc(2026, 9, 2),
        commandId: () => 'durable-command-1',
        jitterUnit: () => 0.5,
        logEvent: (event, _, {data}) => events.add(event),
        scheduleRetry: (_, __) => _FakeTimer(),
      );

  test('persists before dispatch and removes only after canonical apply', () async {
    final plan = testIdentificationPlan();
    final result = testIdentificationResult(plan);
    repository.results.add(result);

    final committed = await service().commit(
      plan,
      playerId: testPlayerId,
      applyCanonicalResult: (_) async => sequence.add('apply'),
    );

    expect(committed, same(result));
    expect(sequence, [
      'enqueue',
      'update:dispatching',
      'commit',
      'apply',
      'update:confirmed',
      'remove',
    ]);
    expect(store.commands, isEmpty);
    expect(events, containsAllInOrder([
      'sync.command.enqueued',
      'sync.command.dispatch_started',
      'sync.command.confirmed',
    ]));
  });

  test('response loss keeps the exact command for idempotent recovery', () async {
    final plan = testIdentificationPlan();
    final result = testIdentificationResult(plan);
    repository.errors.add(
      IdentificationCommitFailure(IdentificationFailureKind.network),
    );
    repository.results.add(result);
    final sync = service();

    await expectLater(
      sync.commit(
        plan,
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<IdentificationSyncPending>()),
    );
    final retained = store.commands.single;
    expect(retained.state, PendingCommandState.retryWait);
    expect(retained.attemptCount, 1);

    await sync.recover(
      playerId: testPlayerId,
      applyCanonicalResult: (_) async => sequence.add('recovered-apply'),
      forceEligible: true,
    );

    expect(repository.plans, hasLength(2));
    expect(repository.plans[1], repository.plans[0]);
    expect(store.commands, isEmpty);
    expect(events, contains('sync.recovery.completed'));
  });

  test('a repeated player action cannot bypass retry backoff', () async {
    final plan = testIdentificationPlan();
    repository.errors.add(
      IdentificationCommitFailure(IdentificationFailureKind.network),
    );
    final sync = service();

    await expectLater(
      sync.commit(
        plan,
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<IdentificationSyncPending>()),
    );
    await expectLater(
      sync.commit(
        plan,
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<IdentificationSyncPending>()),
    );

    expect(repository.plans, hasLength(1));
    expect(store.commands.single.state, PendingCommandState.retryWait);
  });

  test('a same-key different plan is persisted as terminal', () async {
    store.commands.add(testPendingCommand());
    final changedPlan = testIdentificationPlan(
      villagerDisplayName: 'Different Villager',
    );

    await expectLater(
      service().commit(
        changedPlan,
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<IdentificationSyncTerminal>()),
    );

    expect(repository.plans, isEmpty);
    expect(store.commands.single.state, PendingCommandState.terminal);
    expect(store.commands.single.lastFailure, SyncFailureKind.contract);
  });

  test('auth failures pause until authentication resumes', () async {
    final plan = testIdentificationPlan();
    final result = testIdentificationResult(plan);
    repository.errors.add(
      IdentificationCommitFailure(IdentificationFailureKind.auth),
    );
    repository.results.add(result);
    final sync = service();
    var applied = false;

    await expectLater(
      sync.commit(
        plan,
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<IdentificationSyncPending>()),
    );
    expect(store.commands.single.state, PendingCommandState.pausedAuth);

    await sync.resumeAfterAuthentication(
      playerId: testPlayerId,
      applyCanonicalResult: (_) async => applied = true,
    );

    expect(applied, isTrue);
    expect(store.commands, isEmpty);
    expect(events, contains('sync.command.auth_paused'));
  });

  test('scheduled retry uses the provider-lifetime apply callback', () async {
    final plan = testIdentificationPlan();
    final result = testIdentificationResult(plan);
    final scheduled = <void Function()>[];
    final backgroundApplied = Completer<void>();
    var directApplyCount = 0;
    repository.errors.add(
      IdentificationCommitFailure(IdentificationFailureKind.network),
    );
    repository.results.add(result);
    final sync = IdentificationSyncService(
      environment: 'local',
      store: store,
      repository: repository,
      retryPolicy: const SyncRetryPolicy(jitterFraction: 0),
      now: () => DateTime.utc(2026, 9, 2),
      commandId: () => 'durable-command-1',
      jitterUnit: () => 0.5,
      logEvent: (event, _, {data}) => events.add(event),
      backgroundApplyCanonicalResult: (_) async {
        if (!backgroundApplied.isCompleted) backgroundApplied.complete();
      },
      scheduleRetry: (_, callback) {
        scheduled.add(callback);
        return _FakeTimer();
      },
    );

    await expectLater(
      sync.commit(
        plan,
        playerId: testPlayerId,
        applyCanonicalResult: (_) async => directApplyCount++,
      ),
      throwsA(isA<IdentificationSyncPending>()),
    );
    scheduled.single();
    await backgroundApplied.future.timeout(const Duration(seconds: 1));
    for (var index = 0; index < 20 && store.commands.isNotEmpty; index++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(directApplyCount, 0);
    expect(store.commands, isEmpty);
    expect(repository.plans, hasLength(2));
  });

  test('recovery removes an already confirmed command without redispatch', () async {
    store.commands.add(
      testPendingCommand(state: PendingCommandState.confirmed),
    );

    final results = await service().recover(
      playerId: testPlayerId,
      applyCanonicalResult: (_) async {},
    );

    expect(results, isEmpty);
    expect(store.commands, isEmpty);
    expect(repository.plans, isEmpty);
  });

  test('future retry waits and schedules without dispatching', () async {
    final scheduled = <Duration>[];
    store.commands.add(
      testPendingCommand(
        state: PendingCommandState.retryWait,
        nextEligibleAttemptAt: DateTime.utc(2026, 9, 2, 0, 1),
        lastFailure: SyncFailureKind.network,
      ),
    );
    final sync = IdentificationSyncService(
      environment: 'local',
      store: store,
      repository: repository,
      retryPolicy: const SyncRetryPolicy(jitterFraction: 0),
      now: () => DateTime.utc(2026, 9, 2),
      commandId: () => 'durable-command-1',
      jitterUnit: () => 0.5,
      logEvent: (event, _, {data}) => events.add(event),
      scheduleRetry: (delay, _) {
        scheduled.add(delay);
        return _FakeTimer();
      },
    );

    expect(
      await sync.recover(
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      isEmpty,
    );

    expect(scheduled, [const Duration(minutes: 1)]);
    expect(repository.plans, isEmpty);
  });

  test('queue bound and corruption failures emit safe diagnostics', () async {
    store.enqueueError = const QueueBoundFailure();
    await expectLater(
      service().commit(
        testIdentificationPlan(),
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<QueueBoundFailure>()),
    );
    expect(events, contains('sync.queue.bound_exceeded'));
    expect(events, contains('sync.command.enqueue_rejected'));

    events.clear();
    store.enqueueError = null;
    store.loadError = const QueueCorruptFailure();
    await expectLater(
      service().recover(
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<QueueCorruptFailure>()),
    );
    expect(events, contains('sync.queue.corrupt_removed'));
    expect(events, contains('sync.queue.load_failed'));

    events.clear();
    store.loadError = const QueueBoundFailure();
    await expectLater(
      service().recover(
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<QueueBoundFailure>()),
    );
    expect(events, contains('sync.queue.bound_exceeded'));
    expect(events, contains('sync.queue.load_failed'));

    events.clear();
    store.loadError = StateError('private storage detail');
    await expectLater(
      service().recover(
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<StateError>()),
    );
    expect(events, contains('sync.queue.load_failed'));
  });

  test('generic enqueue and purge failures remain safe and observable', () async {
    store.enqueueError = StateError('private write detail');
    await expectLater(
      service().commit(
        testIdentificationPlan(),
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<StateError>()),
    );
    expect(events, contains('sync.command.enqueue_rejected'));

    events.clear();
    store.enqueueError = null;
    store.purgeError = StateError('private purge detail');
    await expectLater(
      service().purge(playerId: testPlayerId),
      throwsA(isA<StateError>()),
    );
    expect(events, contains('sync.queue.purge_failed'));
  });

  test('constructor and clock reject unknown execution scopes', () async {
    expect(
      () => IdentificationSyncService(
        environment: 'beta',
        store: store,
        repository: repository,
        retryPolicy: const SyncRetryPolicy(),
        now: () => DateTime.utc(2026, 9, 2),
        commandId: () => 'command',
        jitterUnit: () => 0.5,
        logEvent: (_, __, {data}) {},
      ),
      throwsArgumentError,
    );
    final sync = IdentificationSyncService(
      environment: 'local',
      store: store,
      repository: repository,
      retryPolicy: const SyncRetryPolicy(),
      now: () => DateTime(2026, 9, 2),
      commandId: () => 'command',
      jitterUnit: () => 0.5,
      logEvent: (_, __, {data}) {},
    );
    await expectLater(
      sync.recover(
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('disposed service refuses new serialized work', () async {
    final sync = service()..dispose();

    await expectLater(
      sync.recover(
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('wrong Player cannot load or dispatch another Player command', () async {
    store.commands.add(testPendingCommand());

    await expectLater(
      service().recover(
        playerId: 'player-2',
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<IdentificationSyncTerminal>()),
    );
    expect(repository.plans, isEmpty);
    expect(store.commands.single.playerId, testPlayerId);
    expect(store.commands.single.state, PendingCommandState.terminal);
  });

  test('terminal failure is inspectable and never automatically retries', () async {
    final plan = testIdentificationPlan();
    repository.errors.add(
      IdentificationCommitFailure(IdentificationFailureKind.contract),
    );

    await expectLater(
      service().commit(
        plan,
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<IdentificationSyncTerminal>()),
    );

    expect(store.commands.single.state, PendingCommandState.terminal);
    expect(events, contains('sync.command.terminal'));
  });

  test('purge cancels retries and emits success only after storage clears', () async {
    final scheduled = <void Function()>[];
    final sync = IdentificationSyncService(
      environment: 'local',
      store: store,
      repository: repository,
      retryPolicy: const SyncRetryPolicy(jitterFraction: 0),
      now: () => DateTime.utc(2026, 9, 2),
      commandId: () => 'durable-command-1',
      jitterUnit: () => 0.5,
      logEvent: (event, _, {data}) => events.add(event),
      scheduleRetry: (_, callback) {
        scheduled.add(callback);
        return _FakeTimer();
      },
    );
    repository.errors.add(
      IdentificationCommitFailure(IdentificationFailureKind.network),
    );
    await expectLater(
      sync.commit(
        testIdentificationPlan(),
        playerId: testPlayerId,
        applyCanonicalResult: (_) async {},
      ),
      throwsA(isA<IdentificationSyncPending>()),
    );

    await sync.purge(playerId: testPlayerId);

    expect(store.commands, isEmpty);
    expect(events.last, 'sync.queue.purged');
    expect(scheduled, hasLength(1));
  });
}

final class _MemoryCommandStore implements PendingCommandStore {
  _MemoryCommandStore(this.sequence);

  final List<String> sequence;
  final List<PendingCommand> commands = [];
  Object? enqueueError;
  Object? loadError;
  Object? purgeError;

  @override
  Future<void> enqueue(PendingCommand command) async {
    final error = enqueueError;
    if (error != null) throw error;
    sequence.add('enqueue');
    commands.add(command);
  }

  @override
  Future<List<PendingCommand>> load({
    required String environment,
    required String playerId,
    required DateTime now,
  }) async {
    final error = loadError;
    if (error != null) throw error;
    return List.unmodifiable(commands);
  }

  @override
  Future<void> remove(PendingCommand command) async {
    sequence.add('remove');
    commands.removeWhere((entry) => entry.commandId == command.commandId);
  }

  @override
  Future<void> replace(PendingCommand command) async {
    sequence.add('update:${command.state.wireName}');
    final index = commands.indexWhere(
      (entry) => entry.commandId == command.commandId,
    );
    commands[index] = command;
  }

  @override
  Future<void> purge({required String environment, required String playerId}) async {
    final error = purgeError;
    if (error != null) throw error;
    commands.removeWhere(
      (entry) => entry.environment == environment && entry.playerId == playerId,
    );
  }
}

final class _RecordingIdentificationRepository
    implements IdentificationRepository {
  _RecordingIdentificationRepository(this.sequence);

  final List<String> sequence;
  final List<ItemIdentificationResult> results = [];
  final List<Object> errors = [];
  final List<ItemIdentificationPlan> plans = [];

  @override
  Future<IdentificationPreparation> prepare(
    ItemKnowledgeItemId itemId, {
    String? traceId,
  }) => throw UnimplementedError();

  @override
  Future<ItemIdentificationResult> commit(
    ItemIdentificationPlan plan, {
    String? traceId,
  }) async {
    sequence.add('commit');
    plans.add(plan);
    if (errors.isNotEmpty) throw errors.removeAt(0);
    return results.removeAt(0);
  }
}

final class _FakeTimer implements Timer {
  @override
  bool get isActive => true;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}
