import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';

enum ExplorationEligibilityPauseReason {
  lowGpsConfidence,
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
}

final explorationEligibilityForMarkerProvider =
    Provider.family<ExplorationEligibility, PlayerMarkerState>((ref, marker) {
  return ExplorationEligibility.fromMarkerState(marker);
});

final explorationEligibilityProvider = Provider<ExplorationEligibility>((ref) {
  final markerState = ref.watch(playerMarkerProvider);
  return ref.watch(explorationEligibilityForMarkerProvider(markerState));
});
