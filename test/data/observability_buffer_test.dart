import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/data/observability_buffer.dart';
import 'package:earth_nova/engine/game_event.dart';

void main() {
  group('ObservabilityBuffer', () {
    test('recordLine stores raw line as app_logs row', () {
      final buffer = ObservabilityBuffer(
        sessionId: '11111111-1111-4111-8111-111111111111',
        deviceId: 'device-1',
      );

      buffer.recordLine('[HYDRATION] started');

      final rows = buffer.drainRows();
      expect(rows, hasLength(1));
      expect(rows.single['session_id'], '11111111-1111-4111-8111-111111111111');
      expect(rows.single['device_id'], 'device-1');
      expect(rows.single['lines'], '[HYDRATION] started');
      expect(rows.single['category'], isNull);
      expect(rows.single['event'], isNull);
      expect(rows.single['data'], isNull);
    });

    test('recordEvent stores structured game event in app_logs shape', () {
      final buffer = ObservabilityBuffer(
        sessionId: '11111111-1111-4111-8111-111111111111',
        deviceId: 'device-1',
        userId: 'user-1',
      );

      final event = GameEvent.cellVisited(
        sessionId: '11111111-1111-4111-8111-111111111111',
        userId: 'user-1',
        deviceId: 'device-1',
        cellId: 'cell_A',
      );

      buffer.recordEvent(event, line: '[ENGINE] cell visited cell_A');

      final rows = buffer.drainRows();
      expect(rows, hasLength(1));
      expect(rows.single['lines'], '[ENGINE] cell visited cell_A');
      expect(rows.single['category'], 'state');
      expect(rows.single['event'], 'cell_visited');
      expect(rows.single['data'], containsPair('cell_id', 'cell_A'));
      expect(rows.single['user_id'], 'user-1');
    });

    test('drainRows empties the buffer', () {
      final buffer = ObservabilityBuffer(
        sessionId: '11111111-1111-4111-8111-111111111111',
      );

      buffer.recordLine('[SYNC] flush started');

      expect(buffer.drainRows(), hasLength(1));
      expect(buffer.drainRows(), isEmpty);
    });

    test('keeps only newest rows when over capacity', () {
      final buffer = ObservabilityBuffer(
        sessionId: '11111111-1111-4111-8111-111111111111',
        maxEntries: 2,
      );

      buffer.recordLine('one');
      buffer.recordLine('two');
      buffer.recordLine('three');

      final rows = buffer.drainRows();
      expect(rows.map((row) => row['lines']), ['two', 'three']);
    });
  });

  group('ObservabilityController', () {
    test('flush uploads buffered rows and clears them on success', () async {
      final uploaded = <List<Map<String, dynamic>>>[];
      final controller = ObservabilityController(
        buffer: ObservabilityBuffer(
          sessionId: '11111111-1111-4111-8111-111111111111',
        ),
        uploader: (rows) async => uploaded.add(rows),
      );

      controller.recordLine('[ENGINE] boot');

      final didFlush = await controller.flush();

      expect(didFlush, isTrue);
      expect(uploaded, hasLength(1));
      expect(uploaded.single.single['lines'], '[ENGINE] boot');
      expect(controller.buffer.drainRows(), isEmpty);
    });

    test('flush requeues rows when upload fails', () async {
      final controller = ObservabilityController(
        buffer: ObservabilityBuffer(
          sessionId: '11111111-1111-4111-8111-111111111111',
        ),
        uploader: (_) async => throw StateError('network down'),
      );

      controller.recordLine('[SYNC] flush started');

      await expectLater(controller.flush(), throwsStateError);
      expect(controller.buffer.drainRows(), hasLength(1));
    });
  });
}
