import 'package:earth_nova/app/sync/application/sync_retry_policy.dart';
import 'package:earth_nova/features/identification/domain/repositories/identification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncRetryPolicy', () {
    const policy = SyncRetryPolicy(jitterFraction: 0);

    test('retries network, rate limiting, and transient server failures', () {
      for (final kind in const [
        IdentificationFailureKind.network,
        IdentificationFailureKind.rateLimited,
        IdentificationFailureKind.transientServer,
      ]) {
        expect(
          policy.classify(IdentificationCommitFailure(kind)),
          SyncFailureDisposition.retryable,
        );
      }
    });

    test('pauses auth and fails closed for unknown or contract failures', () {
      expect(
        policy.classify(
          IdentificationCommitFailure(
            IdentificationFailureKind.auth,
          ),
        ),
        SyncFailureDisposition.pauseForAuth,
      );
      expect(policy.classify(StateError('unknown')), SyncFailureDisposition.terminal);
      expect(
        policy.classify(
          IdentificationCommitFailure(
            IdentificationFailureKind.contract,
          ),
        ),
        SyncFailureDisposition.terminal,
      );
    });

    test('backs off from two seconds and caps at five minutes', () {
      expect(policy.delayForAttempt(1, jitterUnit: 0.5), const Duration(seconds: 2));
      expect(policy.delayForAttempt(2, jitterUnit: 0.5), const Duration(seconds: 4));
      expect(policy.delayForAttempt(20, jitterUnit: 0.5), const Duration(minutes: 5));
    });
  });
}
