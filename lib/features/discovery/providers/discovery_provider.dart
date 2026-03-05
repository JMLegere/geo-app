import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/features/discovery/models/discovery_event.dart';

// ---------------------------------------------------------------------------
// SpeciesService provider (dev fixture — T21 will wire real async load)
// ---------------------------------------------------------------------------

/// Small inline dataset covering Forest + North America encounters for the
/// SF Bay Area simulation. This avoids async loading of the full 6 MB JSON.
///
/// T21 will replace this with a FutureProvider that reads the real asset.
const _kDevSpeciesJson = r'''
[
  {
    "commonName": "Red Fox",
    "scientificName": "Vulpes vulpes",
    "taxonomicClass": "Mammalia",
    "continents": ["North America"],
    "habitats": ["Forest"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Grizzly Bear",
    "scientificName": "Ursus arctos horribilis",
    "taxonomicClass": "Mammalia",
    "continents": ["North America"],
    "habitats": ["Forest"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Gray Wolf",
    "scientificName": "Canis lupus",
    "taxonomicClass": "Mammalia",
    "continents": ["North America"],
    "habitats": ["Forest"],
    "iucnStatus": "Least Concern"
  },
  {
    "commonName": "Jaguar",
    "scientificName": "Panthera onca",
    "taxonomicClass": "Mammalia",
    "continents": ["North America"],
    "habitats": ["Forest"],
    "iucnStatus": "Near Threatened"
  },
  {
    "commonName": "Passenger Pigeon",
    "scientificName": "Ectopistes migratorius",
    "taxonomicClass": "Aves",
    "continents": ["North America"],
    "habitats": ["Forest"],
    "iucnStatus": "Extinct"
  }
]
''';

/// Provides a [SpeciesService] seeded with the dev fixture dataset.
///
/// Synchronous (no asset loading) for use during the SF Bay Area simulation
/// phase. T21 will upgrade to a FutureProvider backed by the full IUCN JSON.
final speciesServiceProvider = Provider<SpeciesService>((ref) {
  final records = (jsonDecode(_kDevSpeciesJson) as List)
      .map((j) => SpeciesRecord.fromJson(j as Map<String, dynamic>))
      .toList();
  return SpeciesService(records);
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
/// Pattern matches `CollectionNotifier` — uses `Notifier` + `NotifierProvider`.
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
