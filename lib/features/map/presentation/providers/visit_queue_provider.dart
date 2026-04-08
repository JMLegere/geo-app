import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/use_cases/record_cell_visit.dart';

class VisitQueueItem {
  const VisitQueueItem({required this.userId, required this.cellId});
  final String userId;
  final String cellId;
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
  @override
  ObservabilityService get obs => ref.watch(visitQueueObservabilityProvider);

  @override
  String get category => 'visit_queue';

  @override
  VisitQueueState build() {
    return const VisitQueueState();
  }

  void enqueue({required String userId, required String cellId}) {
    final newItems = [
      ...state.items,
      VisitQueueItem(userId: userId, cellId: cellId)
    ];
    transition(
      state.copyWith(items: newItems),
      'visit_queue.enqueued',
      data: {'userId': userId, 'cellId': cellId, 'queueSize': newItems.length},
    );
    obs.log('map.visit_queue_enqueued', category, data: {
      'cell_id': cellId,
      'queue_size': newItems.length,
    });
  }

  Future<void> flush(RecordCellVisit useCase) async {
    if (state.items.isEmpty) return;

    final initialCount = state.items.length;
    obs.log('map.visit_queue_flush_started', category, data: {
      'queue_size': initialCount,
    });

    final remaining = <VisitQueueItem>[];
    var anySucceeded = false;
    var anyFailed = false;

    for (final item in state.items) {
      try {
        await useCase.call((userId: item.userId, cellId: item.cellId));
        anySucceeded = true;
      } catch (e) {
        remaining.add(item);
        anyFailed = true;
        obs.log('map.visit_queue_item_failed', category, data: {
          'cell_id': item.cellId,
          'error': e.toString(),
        });
      }
    }

    if (anySucceeded && !anyFailed) {
      final flushedCount = initialCount - remaining.length;
      transition(
        state.copyWith(items: remaining),
        'visit_queue.flushed',
        data: {'flushedCount': flushedCount},
      );
      obs.log('map.visit_queue_flush_success', category, data: {
        'flushed_count': flushedCount,
        'remaining': remaining.length,
      });
    } else if (anySucceeded) {
      final flushedCount = initialCount - remaining.length;
      transition(
        state.copyWith(items: remaining),
        'visit_queue.flushed',
        data: {
          'flushedCount': flushedCount,
          'remainingCount': remaining.length,
        },
      );
      obs.log('map.visit_queue_flush_success', category, data: {
        'flushed_count': flushedCount,
        'remaining': remaining.length,
      });
    } else {
      transition(
        state.copyWith(items: remaining),
        'visit_queue.retry_failed',
        data: {'remainingCount': remaining.length},
      );
    }
  }
}
