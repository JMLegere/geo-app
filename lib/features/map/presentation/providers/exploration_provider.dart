import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_border_crossing_event.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/domain/use_cases/detect_cell_entry.dart';
import 'package:earth_nova/features/map/domain/use_cases/record_cell_visit.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_eligibility_provider.dart';
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
    this.lastBorderCrossingEvent,
  });

  final String? currentCellId;
  final Set<String> visitedCellIds;
  final DateTime? lastVisitTimestamp;
  final String? lastEnteredCellId;
  final bool? lastEntryWasFirstVisit;
  final int lastEntrySequence;
  final CellBorderCrossingEvent? lastBorderCrossingEvent;

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
    CellBorderCrossingEvent? lastBorderCrossingEvent,
    bool clearLastBorderCrossingEvent = false,
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
      lastBorderCrossingEvent: clearLastBorderCrossingEvent
          ? null
          : (lastBorderCrossingEvent ?? this.lastBorderCrossingEvent),
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
    ExplorationEligibility? explorationEligibility,
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

    final canRecordVisits =
        explorationEligibility?.canRecordVisits ?? !markerState.isRing;
    final pauseReason = explorationEligibility?.reason?.name ??
        (markerState.isRing
            ? ExplorationEligibilityPauseReason.lowGpsConfidence.name
            : null);

    // If exploration is paused, track position but do NOT record visits and do
    // NOT create gameplay entry fields. Only log when the tracked cell changes.
    if (!canRecordVisits) {
      if (state.currentCellId == currentCell.id) return;
      transition(
        newState,
        'map.cell_tracked',
        data: {
          'cellId': currentCell.id,
          if (pauseReason != null) 'paused_reason': pauseReason,
        },
      );
      return;
    }

    // A gameplay border crossing only exists after the marker has already been
    // tracked in a previous map cell. Initial occupancy and trusted recovery
    // should establish current context without pretending a border was crossed.
    if (previousCellId == null) {
      transition(
        newState,
        'map.cell_tracked',
        data: {
          'cellId': currentCell.id,
          'tracking_reason': 'initial_occupancy',
        },
      );
      return;
    }

    final isCellEntry = previousCellId != currentCell.id;

    if (!isCellEntry) {
      // Same cell: movement may animate marker/camera, but no border event fires.
      return;
    }

    final now = DateTime.now();

    // Check if this is a first visit.
    final isFirstVisit = !visitedCellIds.contains(currentCell.id) &&
        !state.visitedCellIds.contains(currentCell.id);

    // Record visit optimistically.
    final newVisited = {...state.visitedCellIds, currentCell.id};
    final borderCrossingEvent = _buildBorderCrossingEvent(
      currentCell: currentCell,
      previousCellId: previousCellId,
      isFirstVisit: isFirstVisit,
      occurredAt: now,
      sequence: state.lastEntrySequence + 1,
    );

    newState = newState.copyWith(
      visitedCellIds: newVisited,
      lastVisitTimestamp: now,
      lastEnteredCellId: currentCell.id,
      lastEntryWasFirstVisit: isFirstVisit,
      lastEntrySequence: state.lastEntrySequence + 1,
      lastBorderCrossingEvent: borderCrossingEvent,
    );

    // Log cell_entered event.
    transition(
      newState,
      'map.cell_entered',
      data: {
        'cellId': currentCell.id,
        'isFirstVisit': isFirstVisit,
        'previousCellId': previousCellId,
        ...borderCrossingEvent.toTelemetryData(),
      },
    );

    // Log cell_visited event.
    obs.log(
      'map.cell_visited',
      category,
      data: {
        'cellId': currentCell.id,
        'firstVisit': isFirstVisit,
        ...borderCrossingEvent.toTelemetryData(),
      },
    );

    // If first visit, log fog_cleared event.
    if (isFirstVisit) {
      obs.log(
        'map.fog_cleared',
        category,
        data: {
          'cellId': currentCell.id,
          ...borderCrossingEvent.toTelemetryData(),
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

  CellBorderCrossingEvent _buildBorderCrossingEvent({
    required Cell currentCell,
    required String? previousCellId,
    required bool isFirstVisit,
    required DateTime occurredAt,
    required int sequence,
  }) {
    return CellBorderCrossingEvent(
      borderCrossingId:
          'cell-border-crossing-$sequence-${occurredAt.microsecondsSinceEpoch}',
      previousCellId: previousCellId,
      enteredCellId: currentCell.id,
      borderCrossingType: isFirstVisit
          ? CellBorderCrossingType.firstEntry
          : CellBorderCrossingType.reEntry,
      isFirstVisit: isFirstVisit,
      occurredAt: occurredAt,
      districtId: currentCell.districtId,
      cityId: currentCell.cityId,
      stateId: currentCell.stateId,
      countryId: currentCell.countryId,
    );
  }

  void clearVisitedCells() {
    transition(
      const ExplorationStateData(),
      'map.visited_cells_cleared',
    );
  }
}
