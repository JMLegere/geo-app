/// Web stub for step counting — always returns 0 / empty streams.
///
/// The web platform has no access to hardware pedometers.
/// This stub satisfies the conditional import from `step_service.dart`.
class StepService {
  /// Always-empty stream. Web has no pedometer.
  Stream<int> get stepCountStream => const Stream<int>.empty();

  /// No-op on web.
  void start() {}

  /// Always returns 0 — web has no step counter.
  Future<int> getCurrentStepCount({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return 0;
  }

  /// No-op on web.
  void stop() {}

  /// No-op on web.
  void dispose() {}
}
