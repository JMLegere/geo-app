import 'package:earth_nova/app/sync/domain/pending_command.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_test_data.dart';

void main() {
  group('PendingCommand', () {
    test('accepts the one approved Identification command kind', () {
      final command = testPendingCommand();

      expect(command.kind, PendingCommandKind.identifyItem);
      expect(command.playerId, testPlayerId);
      expect(command.state, PendingCommandState.pending);
    });

    test('rejects blank identities and unsupported environments', () {
      expect(
        () => testPendingCommand(commandId: ' '),
        throwsArgumentError,
      );
      expect(
        () => testPendingCommand(environment: 'beta'),
        throwsArgumentError,
      );
      expect(
        () => testPendingCommand(playerId: ' '),
        throwsArgumentError,
      );
    });

    test('recovers an interrupted dispatch as pending without rerolling', () {
      final dispatching = testPendingCommand(
        state: PendingCommandState.dispatching,
        attemptCount: 2,
      );

      final recovered = dispatching.recoveredAfterRestart();

      expect(recovered.state, PendingCommandState.pending);
      expect(recovered.attemptCount, 2);
      expect(recovered.commandId, dispatching.commandId);
      expect(recovered.idempotencyKey, dispatching.idempotencyKey);
      expect(recovered.payload.plan, dispatching.payload.plan);
    });

    test('requires retry metadata only for retry wait', () {
      expect(
        () => testPendingCommand().copyWith(
          state: PendingCommandState.retryWait,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-UTC and impossible timestamps', () {
      expect(
        () => testPendingCommand(enqueuedAt: DateTime(2026, 9, 1)),
        throwsArgumentError,
      );
      expect(
        () => testPendingCommand(
          state: PendingCommandState.retryWait,
          nextEligibleAttemptAt: DateTime.utc(2026, 8, 31),
        ),
        throwsArgumentError,
      );
      expect(
        () => testPendingCommand(
          state: PendingCommandState.retryWait,
          nextEligibleAttemptAt: DateTime(2026, 9, 2),
        ),
        throwsArgumentError,
      );
    });

    test('rejects unsupported envelope and payload versions', () {
      final seed = testPendingCommand();
      PendingCommand build({required int schema, required int payload}) =>
          PendingCommand(
            schemaVersion: schema,
            commandId: seed.commandId,
            idempotencyKey: seed.idempotencyKey,
            kind: seed.kind,
            payloadVersion: payload,
            payload: seed.payload,
            environment: seed.environment,
            playerId: seed.playerId,
            enqueuedAt: seed.enqueuedAt,
            state: seed.state,
          );

      expect(() => build(schema: 2, payload: 1), throwsArgumentError);
      expect(() => build(schema: 1, payload: 2), throwsArgumentError);
    });

    test('wire enums parse every known value and reject unknown values', () {
      expect(
        PendingCommandKind.parse('identify_item'),
        PendingCommandKind.identifyItem,
      );
      expect(
        () => PendingCommandKind.parse('visit_cell'),
        throwsFormatException,
      );
      for (final state in PendingCommandState.values) {
        expect(PendingCommandState.parse(state.wireName), state);
      }
      expect(
        () => PendingCommandState.parse('mystery'),
        throwsFormatException,
      );
    });
  });
}
