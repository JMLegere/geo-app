import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/core/models/discovery_event.dart';
import 'package:earth_nova/core/state/species_repository_provider.dart';

// ---------------------------------------------------------------------------
// SpeciesService provider (real IUCN dataset — 32,752 species)
// ---------------------------------------------------------------------------

/// Provides a [SpeciesService] backed by the SQLite species repository.
///
/// Returns a cache-backed service when [speciesCacheProvider] is loaded, or an
/// empty [SpeciesService] (no encounters) while the repository is initialising.
///
/// - **Cache ready** — uses [SpeciesService.fromCache] with merged enrichments.
/// - **Loading** — empty [SpeciesService] so the app stays alive until loaded.
final speciesServiceProvider = Provider<SpeciesService>((ref) {
  final cache = ref.watch(speciesCacheProvider);

  if (!cache.isEmpty) {
    return SpeciesService.fromCache(
      cache: cache,
      enrichments: const {}, // Bridge: enrichment merge is now a no-op (FaunaDefinition has stats built in)
    );
  }

  // Cache not ready yet — empty service (no encounters until loaded)
  return SpeciesService(const []);
});

// ---------------------------------------------------------------------------
// DiscoveryState
// ---------------------------------------------------------------------------

/// Maximum number of discovery events kept in [DiscoveryState.recentDiscoveries].
const _kMaxRecentDiscoveries = 20;

/// Maximum number of notifications queued for display.
const kMaxNotificationQueue = 10;

/// Immutable snapshot of the discovery subsystem state.
class DiscoveryState {
  /// Last [_kMaxRecentDiscoveries] discovery events, newest first.
  final List<DiscoveryEvent> recentDiscoveries;

  /// FIFO queue of notifications awaiting display. First item = top card.
  final List<DiscoveryEvent> notificationQueue;

  /// Whether a discovery notification is currently being shown in the UI.
  bool get hasActiveNotification => notificationQueue.isNotEmpty;

  /// The discovery being displayed (top of queue). Null when queue is empty.
  DiscoveryEvent? get currentNotification => notificationQueue.firstOrNull;

  const DiscoveryState({
    this.recentDiscoveries = const [],
    this.notificationQueue = const [],
  });

  DiscoveryState copyWith({
    List<DiscoveryEvent>? recentDiscoveries,
    List<DiscoveryEvent>? notificationQueue,
  }) {
    return DiscoveryState(
      recentDiscoveries: recentDiscoveries ?? this.recentDiscoveries,
      notificationQueue: notificationQueue ?? this.notificationQueue,
    );
  }
}

// ---------------------------------------------------------------------------
// DiscoveryNotifier
// ---------------------------------------------------------------------------

/// Manages the discovery UI state: notification queue and history.
///
/// Wire up by subscribing to `DiscoveryService.onDiscovery` and calling
/// [showDiscovery] for each incoming [DiscoveryEvent].
///
/// Pattern matches `ItemsNotifier` — uses `Notifier` + `NotifierProvider`.
class DiscoveryNotifier extends Notifier<DiscoveryState> {
  @override
  DiscoveryState build() => const DiscoveryState();

  /// Appends [event] to the notification queue and adds it to history.
  ///
  /// Queue is capped at [kMaxNotificationQueue] — oldest queued items are
  /// dropped when the cap is exceeded. History is capped at
  /// [_kMaxRecentDiscoveries].
  void showDiscovery(DiscoveryEvent event) {
    final updatedHistory = [event, ...state.recentDiscoveries]
        .take(_kMaxRecentDiscoveries)
        .toList();
    var updatedQueue = [...state.notificationQueue, event];
    if (updatedQueue.length > kMaxNotificationQueue) {
      updatedQueue = updatedQueue.sublist(
        updatedQueue.length - kMaxNotificationQueue,
      );
    }
    state = state.copyWith(
      recentDiscoveries: updatedHistory,
      notificationQueue: updatedQueue,
    );
  }

  /// Dismisses the top notification (first in queue).
  ///
  /// If the queue still has items after removal, the next one becomes the
  /// active notification automatically.
  void dismissNotification() {
    if (state.notificationQueue.isEmpty) return;
    state = state.copyWith(
      notificationQueue: state.notificationQueue.sublist(1),
    );
  }

  /// Resets the entire discovery state (history + notification).
  void clearHistory() {
    state = const DiscoveryState();
  }
}

/// Global provider for [DiscoveryNotifier].
final discoveryProvider =
    NotifierProvider<DiscoveryNotifier, DiscoveryState>(DiscoveryNotifier.new);
