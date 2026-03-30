import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the map has fully initialized (fog layers, sources, marker).
///
/// Starts `false`. Set to `true` by MapScreen after `_initFogAndReveal()`
/// completes. Used alongside `isHydrated` and `isZoneReady` to gate the
/// loading screen overlay.
final mapReadyProvider = NotifierProvider<MapReadyNotifier, bool>(
  MapReadyNotifier.new,
);

class MapReadyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markReady() {
    state = true;
  }

  void reset() {
    state = false;
  }
}
