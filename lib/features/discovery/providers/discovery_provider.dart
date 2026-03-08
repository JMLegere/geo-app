import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/species/species_data_loader.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/core/models/discovery_event.dart';
import 'package:earth_nova/features/enrichment/providers/enrichment_provider.dart';

// ---------------------------------------------------------------------------
// SpeciesService provider (real IUCN dataset — 32,752 species)
// ---------------------------------------------------------------------------

/// Asynchronously loads [FaunaDefinition] records from the bundled IUCN JSON.
///
/// Uses [rootBundle] so it works in the full app and in widget tests (when the
/// test framework sets up the asset bundle). Records with unknown habitats,
/// continents, or IUCN statuses are silently skipped.
final speciesDataProvider = FutureProvider<List<FaunaDefinition>>((ref) async {
  final jsonString = await rootBundle.loadString('assets/species_data.json');
  return SpeciesDataLoader.fromJsonString(jsonString);
});

/// Provides a [SpeciesService] backed by the full IUCN species dataset.
///
/// - **Loading** — falls back to an empty [SpeciesService] until the asset is
///   ready. No encounters will fire during this brief window.
/// - **Error** — same empty fallback if the asset fails to load.
/// - **Ready** — uses the full 32,752-species dataset.
///
/// Pattern matches [habitatServiceProvider] in biome/.
final speciesServiceProvider = Provider<SpeciesService>((ref) {
  final dataAsync = ref.watch(speciesDataProvider);
  final enrichmentMapAsync = ref.watch(enrichmentMapProvider);
  return dataAsync.when(
    data: (records) {
      final enrichmentMap = enrichmentMapAsync.asData?.value ?? {};
      final enrichedRecords = records.map((def) {
        final enrichment = enrichmentMap[def.id];
        if (enrichment != null) {
          return FaunaDefinition(
            id: def.id,
            displayName: def.displayName,
            scientificName: def.scientificName,
            taxonomicClass: def.taxonomicClass,
            rarity: def.rarity!,
            habitats: def.habitats,
            continents: def.continents,
            seasonRestriction: def.seasonRestriction,
            contextTags: def.contextTags,
            animalClass: enrichment.animalClass,
            foodPreference: enrichment.foodPreference,
            climate: enrichment.climate,
          );
        }
        return def;
      }).toList();
      return SpeciesService(enrichedRecords);
    },
    loading: () => SpeciesService(const []),
    error: (_, __) => SpeciesService(const []),
  );
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
/// Pattern matches `InventoryNotifier` — uses `Notifier` + `NotifierProvider`.
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
