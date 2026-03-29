import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the detection zone has resolved and the map is ready.
///
/// Starts `false`. Set to `true` by [gameCoordinatorProvider] when the
/// detection zone resolves with >0 cells. Used by `_resolveHome` in
/// `main.dart` alongside `playerState.isHydrated` to gate the loading
/// screen.
///
/// Separate from [PlayerState] because zone readiness is game system
/// state, not player profile data.
final zoneReadyProvider = NotifierProvider<ZoneReadyNotifier, bool>(
  ZoneReadyNotifier.new,
);

class ZoneReadyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markReady() {
    state = true;
  }

  void reset() {
    state = false;
  }
}
