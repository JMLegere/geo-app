import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';

enum ExplorationEligibilityPauseReason {
  lowGpsConfidence,
  gpsUnavailable,
}

class ExplorationEligibility {
  const ExplorationEligibility({
    required this.canRecordVisits,
    required this.isPaused,
    required this.reason,
  });

  final bool canRecordVisits;
  final bool isPaused;
  final ExplorationEligibilityPauseReason? reason;

  factory ExplorationEligibility.fromMarkerState(
      PlayerMarkerState markerState) {
    if (markerState.isRing) {
      return const ExplorationEligibility(
        canRecordVisits: false,
        isPaused: true,
        reason: ExplorationEligibilityPauseReason.lowGpsConfidence,
      );
    }

    return const ExplorationEligibility(
      canRecordVisits: true,
      isPaused: false,
      reason: null,
    );
  }

  factory ExplorationEligibility.fromLocationAndMarker(
    LocationProviderState locationState,
    PlayerMarkerState markerState,
  ) {
    if (locationState is LocationProviderPaused ||
        locationState is LocationProviderLoading ||
        locationState is LocationProviderPermissionDenied ||
        locationState is LocationProviderError) {
      return const ExplorationEligibility(
        canRecordVisits: false,
        isPaused: true,
        reason: ExplorationEligibilityPauseReason.gpsUnavailable,
      );
    }

    return ExplorationEligibility.fromMarkerState(markerState);
  }
}

final explorationEligibilityForMarkerProvider =
    Provider.family<ExplorationEligibility, PlayerMarkerState>((ref, marker) {
  return ExplorationEligibility.fromMarkerState(marker);
});

final explorationEligibilityForLocationProvider = Provider.family<
    ExplorationEligibility,
    (LocationProviderState, PlayerMarkerState)>((ref, args) {
  final (locationState, markerState) = args;
  return ExplorationEligibility.fromLocationAndMarker(
      locationState, markerState);
});

final explorationEligibilityProvider = Provider<ExplorationEligibility>((ref) {
  final locationState = ref.watch(locationProvider);
  final markerState = ref.watch(playerMarkerProvider);
  return ExplorationEligibility.fromLocationAndMarker(
      locationState, markerState);
});
