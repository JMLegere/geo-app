import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/core/species/species_data_loader.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/core/models/discovery_event.dart';
import 'package:fog_of_world/features/enrichment/providers/enrichment_provider.dart';

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

/// Immutable snapshot of the discovery subsystem state.
class DiscoveryState {
  /// Last [_kMaxRecentDiscoveries] discovery events, newest first.
  final List<DiscoveryEvent> recentDiscoveries;

  /// Whether a discovery notification is currently being shown in the UI.
  final bool hasActiveNotification;

  /// The discovery being displayed. Non-null when [hasActiveNotification].
  final DiscoveryEvent? currentNotification;

  const DiscoveryState({
    this.recentDiscoveries = const [],
    this.hasActiveNotification = false,
    this.currentNotification,
  });

  DiscoveryState copyWith({
    List<DiscoveryEvent>? recentDiscoveries,
    bool? hasActiveNotification,
    bool clearCurrentNotification = false,
    DiscoveryEvent? currentNotification,
  }) {
    return DiscoveryState(
      recentDiscoveries: recentDiscoveries ?? this.recentDiscoveries,
      hasActiveNotification:
          hasActiveNotification ?? this.hasActiveNotification,
      currentNotification: clearCurrentNotification
          ? null
          : (currentNotification ?? this.currentNotification),
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

  /// Queues [event] as the active notification and adds it to history.
  ///
  /// Replaces any currently-shown notification immediately (new discovery
  /// wins). History is capped at [_kMaxRecentDiscoveries].
  void showDiscovery(DiscoveryEvent event) {
    final updated = [event, ...state.recentDiscoveries]
        .take(_kMaxRecentDiscoveries)
        .toList();
    state = state.copyWith(
      recentDiscoveries: updated,
      hasActiveNotification: true,
      currentNotification: event,
    );
  }

  /// Clears the active notification (called by the overlay after auto-dismiss).
  void dismissNotification() {
    state = state.copyWith(
      hasActiveNotification: false,
      clearCurrentNotification: true,
    );
  }

  /// Resets the entire discovery state (history + notification).
  void clearHistory() {
    state = const DiscoveryState();
  }
}

/// Global provider for [DiscoveryNotifier].
final discoveryProvider =
    NotifierProvider<DiscoveryNotifier, DiscoveryState>(
        DiscoveryNotifier.new);
