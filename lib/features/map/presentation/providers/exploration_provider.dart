import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/domain/use_cases/detect_cell_entry.dart';
import 'package:earth_nova/features/map/domain/use_cases/record_cell_visit.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/visit_queue_provider.dart';

sealed class ExplorationState {
  const ExplorationState();
}

class ExplorationStateData extends ExplorationState {
  const ExplorationStateData({
    this.currentCellId,
    this.visitedCellIds = const {},
    this.lastVisitTimestamp,
    this.lastEnteredCellId,
    this.lastEntryWasFirstVisit,
    this.lastEntrySequence = 0,
  });

  final String? currentCellId;
  final Set<String> visitedCellIds;
  final DateTime? lastVisitTimestamp;
  final String? lastEnteredCellId;
  final bool? lastEntryWasFirstVisit;
  final int lastEntrySequence;

  ExplorationStateData copyWith({
    String? currentCellId,
    bool clearCurrentCellId = false,
    Set<String>? visitedCellIds,
    DateTime? lastVisitTimestamp,
    String? lastEnteredCellId,
    bool clearLastEnteredCellId = false,
    bool? lastEntryWasFirstVisit,
    bool clearLastEntryWasFirstVisit = false,
    int? lastEntrySequence,
  }) {
    return ExplorationStateData(
      currentCellId:
          clearCurrentCellId ? null : (currentCellId ?? this.currentCellId),
      visitedCellIds: visitedCellIds ?? this.visitedCellIds,
      lastVisitTimestamp: lastVisitTimestamp ?? this.lastVisitTimestamp,
      lastEnteredCellId: clearLastEnteredCellId
          ? null
          : (lastEnteredCellId ?? this.lastEnteredCellId),
      lastEntryWasFirstVisit: clearLastEntryWasFirstVisit
          ? null
          : (lastEntryWasFirstVisit ?? this.lastEntryWasFirstVisit),
      lastEntrySequence: lastEntrySequence ?? this.lastEntrySequence,
    );
  }
}

final explorationObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final detectCellEntryProvider = Provider<DetectCellEntry>((ref) {
  return DetectCellEntry(ref.watch(explorationObservabilityProvider));
});

final recordCellVisitProvider = Provider<RecordCellVisit>(
  (ref) {
    ref.watch(observableUseCaseProvider);
    return RecordCellVisit(ref.watch(cellRepositoryProvider),
        ref.watch(explorationObservabilityProvider));
  },
);

final explorationProvider =
    NotifierProvider<ExplorationNotifier, ExplorationStateData>(
  ExplorationNotifier.new,
);

class ExplorationNotifier extends ObservableNotifier<ExplorationStateData> {
  @override
  ObservabilityService get obs => ref.watch(explorationObservabilityProvider);

  @override
  String get category => 'map';

  @override
  ExplorationStateData build() {
    return const ExplorationStateData();
  }

  Future<void> onPositionUpdate({
    required PlayerMarkerState markerState,
    required List<Cell> cells,
    required Set<String> visitedCellIds,
    String? userId,
  }) async {
    if (cells.isEmpty) return;

    final detectCellEntry = ref.read(detectCellEntryProvider);
    final currentPoint = (lat: markerState.lat, lng: markerState.lng);

    // Detect current cell
    final currentCell = detectCellEntry.detectCell(
      cells: cells,
      point: currentPoint,
    );

    if (currentCell == null) {
      // Not in any cell - clear current cell and allow a future re-entry to count.
      if (state.currentCellId != null) {
        transition(
          state.copyWith(
            clearCurrentCellId: true,
            clearLastEnteredCellId: true,
            clearLastEntryWasFirstVisit: true,
          ),
          'map.cell_exited',
          data: {'cellId': state.currentCellId},
        );
      }
      return;
    }

    final previousCellId = state.currentCellId;

    // Update current cell (always track where we are)
    var newState = state.copyWith(currentCellId: currentCell.id);

    // If marker is in ring state, track position but do NOT record visits and do
    // NOT create gameplay entry fields. The marker may be interpolating from a
    // stale point; triggering encounters here causes load-time discovery bursts.
    if (markerState.isRing) {
      transition(newState, 'map.cell_tracked');
      return;
    }

    // A gameplay entry means this confident marker has not recorded an entry for
    // the current occupancy yet. Ring-state tracking may have already set
    // currentCellId, so currentCellId alone cannot decide whether a visit is due.
    final isCellEntry = state.lastEnteredCellId != currentCell.id;

    if (!isCellEntry) {
      // Same confident cell after an already-recorded entry: state is unchanged.
      return;
    }

    // Check if this is a first visit.
    final isFirstVisit = !visitedCellIds.contains(currentCell.id) &&
        !state.visitedCellIds.contains(currentCell.id);

    // Record visit optimistically.
    final now = DateTime.now();
    final newVisited = {...state.visitedCellIds, currentCell.id};

    newState = newState.copyWith(
      visitedCellIds: newVisited,
      lastVisitTimestamp: now,
      lastEnteredCellId: currentCell.id,
      lastEntryWasFirstVisit: isFirstVisit,
      lastEntrySequence: state.lastEntrySequence + 1,
    );

    // Log cell_entered event.
    transition(
      newState,
      'map.cell_entered',
      data: {
        'cellId': currentCell.id,
        'isFirstVisit': isFirstVisit,
        'previousCellId': previousCellId,
      },
    );

    // Log cell_visited event.
    obs.log(
      'map.cell_visited',
      category,
      data: {
        'cellId': currentCell.id,
        'firstVisit': isFirstVisit,
      },
    );

    // If first visit, log fog_cleared event.
    if (isFirstVisit) {
      obs.log(
        'map.fog_cleared',
        category,
        data: {
          'cellId': currentCell.id,
        },
      );
    }

    // Persist visit to backend; enqueue on failure.
    if (userId != null && userId.isNotEmpty) {
      final recordVisit = ref.read(recordCellVisitProvider);
      try {
        await recordVisit.call((
          userId: userId,
          cellId: currentCell.id,
        ));
      } catch (_) {
        ref.read(visitQueueProvider.notifier).enqueue(
              userId: userId,
              cellId: currentCell.id,
            );
      }
    }
  }

  void clearVisitedCells() {
    transition(
      const ExplorationStateData(),
      'map.visited_cells_cleared',
    );
  }
}
