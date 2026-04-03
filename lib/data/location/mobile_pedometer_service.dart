import 'package:pedometer_2/pedometer_2.dart';

import 'package:earth_nova/providers/step_provider.dart';

/// Real pedometer implementation backed by [pedometer_2].
///
/// Uses the OS cumulative step counter via [Pedometer.getStepCount].
/// Falls back to 0 on any error or timeout so the app never hangs on
/// devices without a hardware step counter.
class MobilePedometerService implements PedometerService {
  final _pedometer = Pedometer();

  @override
  Future<int> getCurrentStepCount() async {
    try {
      final count = await _pedometer
          .getStepCount()
          .timeout(const Duration(seconds: 3), onTimeout: () => 0);
      return count;
    } catch (_) {
      return 0;
    }
  }

  @override
  void dispose() {}
}
