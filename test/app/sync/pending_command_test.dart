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
  });
}
