import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the rubber-band marker has converged to within
/// [kPlayerLocatedThresholdMeters] of the raw GPS position.
///
/// Starts `false`. Set to `true` by MapScreen when the display position
/// is within threshold of GPS, or by the 15s startup timeout fallback.
final playerLocatedProvider = NotifierProvider<PlayerLocatedNotifier, bool>(
  PlayerLocatedNotifier.new,
);

class PlayerLocatedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markLocated() {
    state = true;
  }

  void reset() {
    state = false;
  }
}
