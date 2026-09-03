import 'dart:math' as math;

import 'package:earth_nova/features/identification/domain/repositories/identification_repository.dart';

enum SyncFailureDisposition { retryable, pauseForAuth, terminal }

final class SyncRetryPolicy {
  const SyncRetryPolicy({this.jitterFraction = 0.2})
    : assert(jitterFraction >= 0 && jitterFraction <= 1);

  final double jitterFraction;

  SyncFailureDisposition classify(Object error) {
    if (error is! IdentificationCommitFailure) {
      return SyncFailureDisposition.terminal;
    }
    return switch (error.kind) {
      IdentificationFailureKind.network ||
      IdentificationFailureKind.rateLimited ||
      IdentificationFailureKind.transientServer =>
        SyncFailureDisposition.retryable,
      IdentificationFailureKind.auth => SyncFailureDisposition.pauseForAuth,
      IdentificationFailureKind.validation ||
      IdentificationFailureKind.permission ||
      IdentificationFailureKind.ownership ||
      IdentificationFailureKind.contract ||
      IdentificationFailureKind.unknown => SyncFailureDisposition.terminal,
    };
  }

  Duration delayForAttempt(int attempt, {required double jitterUnit}) {
    if (attempt <= 0) throw ArgumentError.value(attempt, 'attempt');
    if (!jitterUnit.isFinite || jitterUnit < 0 || jitterUnit > 1) {
      throw ArgumentError.value(jitterUnit, 'jitterUnit');
    }
    final exponent = math.min(attempt - 1, 8);
    final baseMilliseconds = math.min(2000 * (1 << exponent), 300000);
    final jitter = (baseMilliseconds * jitterFraction * (jitterUnit - 0.5))
        .round();
    return Duration(
      milliseconds: (baseMilliseconds + jitter).clamp(1, 300000).toInt(),
    );
  }
}
