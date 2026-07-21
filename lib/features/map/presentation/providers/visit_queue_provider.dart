import 'package:earth_nova/features/encounters/presentation/providers/encounter_entry_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell_border_crossing_event.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/map/domain/use_cases/record_cell_visit.dart';

class VisitQueueItem {
  const VisitQueueItem({
    required this.queueId,
    required this.userId,
    required this.cellId,
    required this.clientEventId,
    required this.borderCrossingEvent,
    this.rootTrace,
    this.persistedCellVisit,
  });

  final String queueId;
  final String userId;
  final String cellId;
  final String clientEventId;
  final CellBorderCrossingEvent borderCrossingEvent;
  final TraceContext? rootTrace;

  final CellVisit? persistedCellVisit;

  VisitQueueItem copyWith({
    CellVisit? persistedCellVisit,
    TraceContext? rootTrace,
  }) {
    return VisitQueueItem(
      queueId: queueId,
      userId: userId,
      cellId: cellId,
      clientEventId: clientEventId,
      borderCrossingEvent: borderCrossingEvent,
      rootTrace: rootTrace ?? this.rootTrace,
      persistedCellVisit: persistedCellVisit ?? this.persistedCellVisit,
    );
  }
}

class VisitQueueState {
  const VisitQueueState({this.items = const []});

  final List<VisitQueueItem> items;

  int get pendingCount => items.length;

  VisitQueueState copyWith({List<VisitQueueItem>? items}) {
    return VisitQueueState(items: items ?? this.items);
  }
}

final visitQueueObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final visitQueueProvider =
    NotifierProvider<VisitQueueNotifier, VisitQueueState>(
  VisitQueueNotifier.new,
);

class VisitQueueNotifier extends ObservableNotifier<VisitQueueState> {
  Future<void>? _activeFlush;
  var _nextQueueId = 0;

  @override
  ObservabilityService get obs => ref.watch(visitQueueObservabilityProvider);

  @override
  String get category => 'visit_queue';

  @override
  VisitQueueState build() {
    return const VisitQueueState();
  }

  void enqueue({
    required String userId,
    required String cellId,
    required String clientEventId,
    required CellBorderCrossingEvent borderCrossingEvent,
    CellVisit? persistedCellVisit,
    TraceContext? rootTrace,
  }) {
    final item = VisitQueueItem(
      queueId: 'queued-cell-visit-${++_nextQueueId}',
      userId: userId,
      cellId: cellId,
      clientEventId: clientEventId,
      borderCrossingEvent: borderCrossingEvent,
      rootTrace: rootTrace,
      persistedCellVisit: persistedCellVisit,
    );
    final newItems = [...state.items, item];
    transition(
      state.copyWith(items: newItems),
      'visit_queue.enqueued',
      data: {'queueSize': newItems.length},
    );
    obs.log('map.visit_queue_enqueued', category, data: {
      'queue_size': newItems.length,
      'has_persisted_visit': persistedCellVisit != null,
    });
  }

  Future<void> flush({
    required RecordCellVisit recordVisit,
    required PersistedCellVisitEncounterHandler encounterHandler,
  }) {
    final activeFlush = _activeFlush;
    if (activeFlush != null) return activeFlush;

    late final Future<void> flush;
    flush = _flush(
      recordVisit: recordVisit,
      encounterHandler: encounterHandler,
    ).whenComplete(() {
      if (identical(_activeFlush, flush)) {
        _activeFlush = null;
      }
    });
    _activeFlush = flush;
    return flush;
  }

  Future<void> _flush({
    required RecordCellVisit recordVisit,
    required PersistedCellVisitEncounterHandler encounterHandler,
  }) async {
    final snapshot = List<VisitQueueItem>.of(state.items);
    if (snapshot.isEmpty) return;

    obs.log('map.visit_queue_flush_started', category, data: {
      'queue_size': snapshot.length,
    });

    var handoffsSucceeded = 0;
    var failures = 0;
    for (final snapshotItem in snapshot) {
      final item = _itemWithQueueId(snapshotItem.queueId);
      if (item == null) continue;

      final rootTrace = item.rootTrace ?? TraceContext.start();
      if (item.rootTrace == null) {
        _replaceRootTrace(item.queueId, rootTrace);
      }
      var persistedCellVisit = item.persistedCellVisit;
      if (persistedCellVisit == null) {
        try {
          persistedCellVisit = await recordVisit.call(
            (
              userId: item.userId,
              cellId: item.cellId,
              clientEventId: item.clientEventId,
            ),
            parent: rootTrace,
          );
          _replacePersistedCellVisit(item.queueId, persistedCellVisit);
        } catch (_) {
          failures += 1;
          _logItemFailure(stage: 'persistence');
          continue;
        }
      }

      try {
        await encounterHandler(
          persistedCellVisit,
          item.borderCrossingEvent,
          rootTrace: rootTrace,
        );
        _removeByQueueId(item.queueId);
        handoffsSucceeded += 1;
      } catch (_) {
        failures += 1;
        _logItemFailure(stage: 'coordination');
      }
    }

    final remainingCount = state.items.length;
    if (handoffsSucceeded > 0) {
      transition(
        state,
        'visit_queue.flushed',
        data: {
          'flushedCount': handoffsSucceeded,
          'remainingCount': remainingCount,
        },
      );
      obs.log('map.visit_queue_flush_success', category, data: {
        'flushed_count': handoffsSucceeded,
        'remaining': remainingCount,
      });
    }
    if (failures > 0 && handoffsSucceeded == 0) {
      transition(
        state,
        'visit_queue.retry_failed',
        data: {'remainingCount': remainingCount},
      );
    }
  }

  VisitQueueItem? _itemWithQueueId(String queueId) {
    for (final item in state.items) {
      if (item.queueId == queueId) return item;
    }
    return null;
  }

  void _replacePersistedCellVisit(
      String queueId, CellVisit persistedCellVisit) {
    final items = state.items
        .map(
          (item) => item.queueId == queueId
              ? item.copyWith(persistedCellVisit: persistedCellVisit)
              : item,
        )
        .toList(growable: false);
    transition(
      state.copyWith(items: items),
      'visit_queue.persisted',
      data: {'queueSize': items.length},
    );
  }

  void _replaceRootTrace(String queueId, TraceContext rootTrace) {
    final items = state.items
        .map(
          (item) => item.queueId == queueId
              ? item.copyWith(rootTrace: rootTrace)
              : item,
        )
        .toList(growable: false);
    transition(
      state.copyWith(items: items),
      'visit_queue.trace_bound',
      data: {'queueSize': items.length},
    );
  }

  void _removeByQueueId(String queueId) {
    final items = state.items
        .where((item) => item.queueId != queueId)
        .toList(growable: false);
    transition(
      state.copyWith(items: items),
      'visit_queue.handed_off',
      data: {'queueSize': items.length},
    );
  }

  void _logItemFailure({required String stage}) {
    obs.log('map.visit_queue_item_failed', category, data: {'stage': stage});
  }
}
