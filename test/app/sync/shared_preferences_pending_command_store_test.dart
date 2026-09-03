import 'package:earth_nova/app/sync/data/shared_preferences_pending_command_store.dart';
import 'package:earth_nova/app/sync/domain/pending_command.dart';
import 'package:earth_nova/app/sync/domain/pending_command_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late SharedPreferencesPendingCommandStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = SharedPreferencesPendingCommandStore(preferences);
  });

  test('round trips the exact Identification plan separately by owner', () async {
    final command = PendingCommand(
      schemaVersion: PendingCommand.currentSchemaVersion,
      commandId: 'command-with-properties',
      idempotencyKey: 'identify:item-with-properties',
      kind: PendingCommandKind.identifyItem,
      payloadVersion: IdentificationCommandPayload.currentVersion,
      payload: IdentificationCommandPayload(
        plan: testIdentificationPlan(
          itemId: 'item-with-properties',
          includeProperties: true,
        ),
      ),
      environment: 'local',
      playerId: testPlayerId,
      enqueuedAt: DateTime.utc(2026, 9, 1),
      state: PendingCommandState.pending,
    );
    await store.enqueue(command);

    final loaded = await store.load(
      environment: 'local',
      playerId: testPlayerId,
      now: DateTime.utc(2026, 9, 2),
    );

    expect(loaded, hasLength(1));
    expect(loaded.single.commandId, command.commandId);
    expect(loaded.single.payload.plan, command.payload.plan);
    expect(
      await store.load(
        environment: 'prod',
        playerId: testPlayerId,
        now: DateTime.utc(2026, 9, 2),
      ),
      isEmpty,
    );
  });

  test('normalizes dispatching to pending on validated reload', () async {
    await store.enqueue(
      testPendingCommand(state: PendingCommandState.dispatching),
    );

    final loaded = await store.load(
      environment: 'local',
      playerId: testPlayerId,
      now: DateTime.utc(2026, 9, 2),
    );

    expect(loaded.single.state, PendingCommandState.pending);
  });

  test('rejects an oversized payload and preserves the last queue', () async {
    final original = testPendingCommand();
    await store.enqueue(original);
    final oversized = PendingCommand(
      schemaVersion: PendingCommand.currentSchemaVersion,
      commandId: 'command-2',
      idempotencyKey: 'identify:item-2',
      kind: PendingCommandKind.identifyItem,
      payloadVersion: IdentificationCommandPayload.currentVersion,
      payload: IdentificationCommandPayload(
        plan: testIdentificationPlan(
          itemId: 'item-2',
          villagerDisplayName: List.filled(17000, 'x').join(),
        ),
      ),
      environment: 'local',
      playerId: testPlayerId,
      enqueuedAt: DateTime.utc(2026, 9, 1),
      state: PendingCommandState.pending,
    );

    await expectLater(store.enqueue(oversized), throwsA(isA<QueueBoundFailure>()));
    final loaded = await store.load(
      environment: 'local',
      playerId: testPlayerId,
      now: DateTime.utc(2026, 9, 2),
    );
    expect(loaded.map((entry) => entry.commandId), [original.commandId]);
  });

  test('removes corrupt storage instead of guessing', () async {
    await preferences.setString(
      'pending_commands.v1.local.$testPlayerId',
      '{"version":1,"commands":[{"state":"mystery"}]}',
    );

    await expectLater(
      store.load(
        environment: 'local',
        playerId: testPlayerId,
        now: DateTime.utc(2026, 9, 2),
      ),
      throwsA(isA<QueueCorruptFailure>()),
    );
    expect(preferences.getKeys(), isEmpty);
  });

  test('removes an over-count or expired queue instead of truncating it', () async {
    final key = 'pending_commands.v1.local.$testPlayerId';
    await preferences.setString(
      key,
      jsonEncode({
        'version': 1,
        'environment': 'local',
        'playerId': testPlayerId,
        'commands': List<Object?>.filled(101, const {}),
      }),
    );
    await expectLater(
      store.load(
        environment: 'local',
        playerId: testPlayerId,
        now: DateTime.utc(2026, 9, 2),
      ),
      throwsA(isA<QueueBoundFailure>()),
    );
    expect(preferences.containsKey(key), isFalse);

    await store.enqueue(testPendingCommand());
    await expectLater(
      store.load(
        environment: 'local',
        playerId: testPlayerId,
        now: DateTime.utc(2026, 9, 10),
      ),
      throwsA(isA<QueueBoundFailure>()),
    );
    expect(preferences.containsKey(key), isFalse);
  });

  test('purges current and prior queue versions for one owner only', () async {
    await store.enqueue(testPendingCommand());
    await preferences.setString(
      'pending_commands.v0.local.$testPlayerId',
      'legacy',
    );
    await preferences.setString('pending_commands.v0.prod.$testPlayerId', 'keep');

    await store.purge(environment: 'local', playerId: testPlayerId);

    expect(
      preferences.getKeys(),
      {'pending_commands.v0.prod.$testPlayerId'},
    );
  });
}
import 'dart:convert';
