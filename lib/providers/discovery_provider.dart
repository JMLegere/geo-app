import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/engine/game_event.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class DiscoveryState {
  /// Toast queue — head is the active toast, rest are waiting.
  final List<GameEvent> toastQueue;

  const DiscoveryState({this.toastQueue = const []});

  DiscoveryState copyWith({List<GameEvent>? toastQueue}) =>
      DiscoveryState(toastQueue: toastQueue ?? this.toastQueue);

  GameEvent? get activeToast => toastQueue.isNotEmpty ? toastQueue.first : null;
}

// ---------------------------------------------------------------------------
// Provider + Notifier
// ---------------------------------------------------------------------------

final discoveryProvider =
    NotifierProvider<DiscoveryNotifier, DiscoveryState>(DiscoveryNotifier.new);

class DiscoveryNotifier extends Notifier<DiscoveryState> {
  @override
  DiscoveryState build() => const DiscoveryState();

  /// Append a discovery event to the toast queue.
  void enqueueToast(GameEvent event) {
    state = state.copyWith(
      toastQueue: [...state.toastQueue, event],
    );
  }

  /// Remove the front-of-queue toast (called when toast animation completes).
  void dismissToast() {
    if (state.toastQueue.isEmpty) return;
    state = state.copyWith(
      toastQueue: state.toastQueue.skip(1).toList(),
    );
  }

  /// Clear all pending toasts (e.g., on sign-out).
  void clearAll() => state = const DiscoveryState();
}
