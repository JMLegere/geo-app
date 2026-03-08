import 'dart:async';

import 'package:pedometer_2/pedometer_2.dart';

/// Native step counting service using device accelerometer via pedometer_2.
///
/// The OS step counter runs continuously — even when the app is killed.
/// [stepCountStream] emits the OS's running total (steps since last reboot
/// on Android, or CMPedometer cumulative on iOS). Callers compute deltas.
class StepService {
  StreamSubscription<StepCount>? _subscription;
  final _controller = StreamController<int>.broadcast();

  /// Stream of the OS's cumulative step count. Emits whenever the
  /// pedometer reports a new value (~once per second when walking).
  Stream<int> get stepCountStream => _controller.stream;

  /// Starts listening to the hardware pedometer.
  void start() {
    _subscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        _controller.add(event.steps);
      },
      onError: (Object error) {
        // Pedometer unavailable or permission denied — emit nothing.
        // UI will show 0 steps gracefully.
      },
    );
  }

  /// Gets the current step count as a one-shot future.
  ///
  /// Subscribes to the pedometer stream, takes the first value, and
  /// returns it. Returns 0 if no value arrives within [timeout].
  Future<int> getCurrentStepCount({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<int>();
    StreamSubscription<StepCount>? sub;

    sub = Pedometer.stepCountStream.listen(
      (StepCount event) {
        if (!completer.isCompleted) {
          completer.complete(event.steps);
        }
        sub?.cancel();
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.complete(0);
        }
        sub?.cancel();
      },
    );

    // Timeout fallback — pedometer may not emit if device is stationary.
    return completer.future.timeout(timeout, onTimeout: () {
      sub?.cancel();
      return 0;
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
