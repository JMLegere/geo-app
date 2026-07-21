import 'dart:async';

import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_border_crossing_event.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:earth_nova/features/map/domain/use_cases/record_cell_visit.dart';
import 'package:earth_nova/features/map/presentation/providers/visit_queue_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, Map<String, dynamic>? data})> events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, data: data));
  }
}

class _FakeCellRepository implements CellRepository {
  bool shouldThrow = false;
  Future<CellVisit> Function(
    String userId,
    String cellId,
    String clientEventId,
  )? onRecord;
  final List<({String userId, String cellId, String clientEventId})>
      recordInputs = [];

  @override
  Future<List<Cell>> fetchCellsInRadius(
    double lat,
    double lng,
    double radiusMeters, {
    String? traceId,
  }) async =>
      [];

  @override
  Future<CellVisit> recordVisit(
    String userId,
    String cellId,
    String clientEventId, {
    String? traceId,
  }) async {
    recordInputs.add((
      userId: userId,
      cellId: cellId,
      clientEventId: clientEventId,
    ));
    if (shouldThrow) throw StateError('backend unavailable');
    final callback = onRecord;
    if (callback != null) return callback(userId, cellId, clientEventId);
    return _visit(userId, cellId, clientEventId, recordInputs.length);
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId,
          {String? traceId}) async =>
      {};

  @override
  Future<bool> isFirstVisit(
    String userId,
    String cellId, {
    String? traceId,
  }) async =>
      true;
}

CellVisit _visit(
  String userId,
  String cellId,
  String clientEventId,
  int sequence,
) {
  return CellVisit(
    id: 'visit-$sequence',
    userId: userId,
    cellId: cellId,
    clientEventId: clientEventId,
    visitedAt: DateTime.utc(2026, 7, 20),
  );
}

CellBorderCrossingEvent _event(String id, {String cellId = 'cell-1'}) {
  return CellBorderCrossingEvent(
    borderCrossingId: id,
    previousCellId: 'cell-0',
    enteredCellId: cellId,
    borderCrossingType: CellBorderCrossingType.firstEntry,
    isFirstVisit: true,
    occurredAt: DateTime.utc(2026, 7, 20),
    districtId: 'district-1',
    cityId: 'city-1',
    stateId: 'state-1',
    countryId: 'country-1',
  );
}

void main() {
  group('VisitQueueNotifier', () {
    late ProviderContainer container;
    late _FakeCellRepository repository;
    late TestObservabilityService observability;
    late RecordCellVisit recordVisit;
    late VisitQueueNotifier notifier;

    setUp(() {
      repository = _FakeCellRepository();
      observability = TestObservabilityService();
      recordVisit = RecordCellVisit(repository, observability);
      container = ProviderContainer(
        overrides: [
          visitQueueObservabilityProvider.overrideWithValue(observability),
        ],
      );
      notifier = container.read(visitQueueProvider.notifier);
    });

    tearDown(() => container.dispose());

    void enqueue(String eventId, {CellVisit? persistedCellVisit}) {
      final event = _event(eventId);
      notifier.enqueue(
        userId: 'user-1',
        cellId: event.enteredCellId,
        clientEventId: event.mapCellEntryId,
        borderCrossingEvent: event,
        persistedCellVisit: persistedCellVisit,
      );
    }

    test('keeps stable queue identity and exact border entry identity', () {
      final event = _event(' raw-entry-id ');
      notifier.enqueue(
        userId: 'user-1',
        cellId: event.enteredCellId,
        clientEventId: event.mapCellEntryId,
        borderCrossingEvent: event,
      );

      final item = container.read(visitQueueProvider).items.single;
      expect(item.queueId, isNotEmpty);
      expect(item.userId, 'user-1');
      expect(item.cellId, 'cell-1');
      expect(item.clientEventId, ' raw-entry-id ');
      expect(item.borderCrossingEvent, same(event));
      expect(item.persistedCellVisit, isNull);
    });

    test('reuses one exact event ID across persistence retries and handoff',
        () async {
      final event = _event('entry-id-1');
      notifier.enqueue(
        userId: 'user-1',
        cellId: event.enteredCellId,
        clientEventId: event.mapCellEntryId,
        borderCrossingEvent: event,
      );
      repository.shouldThrow = true;

      await notifier.flush(
        recordVisit: recordVisit,
        encounterHandler: (_, __, {rootTrace}) async {},
      );
      repository.shouldThrow = false;

      CellVisit? handedOffVisit;
      CellBorderCrossingEvent? handedOffEvent;
      await notifier.flush(
        recordVisit: recordVisit,
        encounterHandler: (visit, borderEvent, {rootTrace}) async {
          handedOffVisit = visit;
          handedOffEvent = borderEvent;
        },
      );

      expect(
        repository.recordInputs.map((input) => input.clientEventId),
        ['entry-id-1', 'entry-id-1'],
      );
      expect(handedOffVisit?.clientEventId, 'entry-id-1');
      expect(handedOffEvent, same(event));
      expect(container.read(visitQueueProvider).items, isEmpty);
    });

    test(
        'retries coordinator failure with exact persisted visit, not record call',
        () async {
      final event = _event('entry-id-2');
      notifier.enqueue(
        userId: 'user-1',
        cellId: event.enteredCellId,
        clientEventId: event.mapCellEntryId,
        borderCrossingEvent: event,
      );
      CellVisit? firstVisit;
      TraceContext? firstRootTrace;

      await notifier.flush(
        recordVisit: recordVisit,
        encounterHandler: (visit, borderEvent, {rootTrace}) async {
          firstRootTrace = rootTrace;
          firstVisit = visit;
          expect(borderEvent.mapCellEntryId, event.mapCellEntryId);
          throw StateError('coordination failure');
        },
      );

      final retained = container.read(visitQueueProvider).items.single;
      expect(retained.persistedCellVisit, same(firstVisit));
      expect(repository.recordInputs, hasLength(1));

      CellVisit? retriedVisit;
      CellBorderCrossingEvent? retriedEvent;
      TraceContext? retriedRootTrace;
      await notifier.flush(
        recordVisit: recordVisit,
        encounterHandler: (visit, borderEvent, {rootTrace}) async {
          retriedRootTrace = rootTrace;
          retriedVisit = visit;
          retriedEvent = borderEvent;
        },
      );

      expect(repository.recordInputs, hasLength(1));
      expect(retriedVisit, same(firstVisit));
      expect(retriedEvent, same(event));
      expect(container.read(visitQueueProvider).items, isEmpty);
      expect(retriedRootTrace, same(firstRootTrace));
    });

    test('preserves an item enqueued while a flush awaits', () async {
      final firstPersist = Completer<CellVisit>();
      repository.onRecord =
          (userId, cellId, clientEventId) => firstPersist.future;
      enqueue('entry-id-3');

      final flushing = notifier.flush(
        recordVisit: recordVisit,
        encounterHandler: (_, __, {rootTrace}) async {},
      );
      await Future<void>.delayed(Duration.zero);
      enqueue('entry-id-4');
      firstPersist.complete(_visit('user-1', 'cell-1', 'entry-id-3', 1));
      await flushing;

      final retained = container.read(visitQueueProvider).items.single;
      expect(retained.clientEventId, 'entry-id-4');
      expect(retained.persistedCellVisit, isNull);
    });

    test('serializes overlapping flush calls', () async {
      final persist = Completer<CellVisit>();
      repository.onRecord = (userId, cellId, clientEventId) => persist.future;
      enqueue('entry-id-5');

      final firstFlush = notifier.flush(
        recordVisit: recordVisit,
        encounterHandler: (_, __, {rootTrace}) async {},
      );
      final overlappingFlush = notifier.flush(
        recordVisit: recordVisit,
        encounterHandler: (_, __, {rootTrace}) async {},
      );

      expect(identical(firstFlush, overlappingFlush), isTrue);
      expect(repository.recordInputs, hasLength(1));
      persist.complete(_visit('user-1', 'cell-1', 'entry-id-5', 1));
      await Future.wait([firstFlush, overlappingFlush]);
      expect(repository.recordInputs, hasLength(1));
      expect(container.read(visitQueueProvider).items, isEmpty);
    });

    test('removes only the item whose Encounter handoff succeeds', () async {
      enqueue('entry-id-6');
      enqueue('entry-id-7');

      await notifier.flush(
        recordVisit: recordVisit,
        encounterHandler: (_, event, {rootTrace}) async {
          if (event.mapCellEntryId == 'entry-id-7') {
            throw StateError('coordination failure');
          }
        },
      );

      final retained = container.read(visitQueueProvider).items.single;
      expect(retained.clientEventId, 'entry-id-7');
      expect(retained.persistedCellVisit?.clientEventId, 'entry-id-7');
      expect(repository.recordInputs, hasLength(2));
      final failure = observability.events.singleWhere(
        (event) => event.event == 'map.visit_queue_item_failed',
      );
      expect(failure.data, {'stage': 'coordination'});
    });
  });
}
