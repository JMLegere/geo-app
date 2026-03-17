import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/world/services/restoration_service.dart';

void main() {
  group('RestorationService', () {
    late RestorationService service;

    setUp(() {
      service = RestorationService();
    });

    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    test('new cell starts at restoration 0.0', () {
      expect(service.getRestorationLevel('cell1'), equals(0.0));
    });

    test('unknown cell reports 0.0 from isFullyRestored', () {
      expect(service.isFullyRestored('unknown'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Species collection increases level
    // -------------------------------------------------------------------------

    test('collecting 1 species adds approximately 0.33', () {
      service.recordCollection('cell1', 'sp1');
      expect(service.getRestorationLevel('cell1'), closeTo(1 / 3, 0.001));
    });

    test('collecting 2 species adds approximately 0.66', () {
      service.recordCollection('cell1', 'sp1');
      service.recordCollection('cell1', 'sp2');
      expect(service.getRestorationLevel('cell1'), closeTo(2 / 3, 0.001));
    });

    test('collecting 3 species reaches exactly 1.0', () {
      service.recordCollection('cell1', 'sp1');
      service.recordCollection('cell1', 'sp2');
      service.recordCollection('cell1', 'sp3');
      expect(service.getRestorationLevel('cell1'), equals(1.0));
    });

    // -------------------------------------------------------------------------
    // Duplicate species are ignored
    // -------------------------------------------------------------------------

    test('collecting same species twice does not increase level', () {
      service.recordCollection('cell1', 'sp1');
      service.recordCollection('cell1', 'sp1');
      expect(service.getRestorationLevel('cell1'), closeTo(1 / 3, 0.001));
    });

    test('collecting same species 5 times counts as one species', () {
      for (var i = 0; i < 5; i++) {
        service.recordCollection('cell1', 'sp1');
      }
      expect(service.getRestorationLevel('cell1'), closeTo(1 / 3, 0.001));
    });

    // -------------------------------------------------------------------------
    // Capped at 1.0
    // -------------------------------------------------------------------------

    test('restoration is capped at 1.0 when collecting 4+ species', () {
      service.recordCollection('cell1', 'sp1');
      service.recordCollection('cell1', 'sp2');
      service.recordCollection('cell1', 'sp3');
      service.recordCollection('cell1', 'sp4');
      expect(service.getRestorationLevel('cell1'), equals(1.0));
    });

    test('restoration stays at 1.0 even with 10 unique species', () {
      for (var i = 1; i <= 10; i++) {
        service.recordCollection('cell1', 'sp$i');
      }
      expect(service.getRestorationLevel('cell1'), equals(1.0));
    });

    // -------------------------------------------------------------------------
    // isFullyRestored
    // -------------------------------------------------------------------------

    test('isFullyRestored returns false before 3 species', () {
      service.recordCollection('cell1', 'sp1');
      service.recordCollection('cell1', 'sp2');
      expect(service.isFullyRestored('cell1'), isFalse);
    });

    test('isFullyRestored returns true at exactly 3 species', () {
      service.recordCollection('cell1', 'sp1');
      service.recordCollection('cell1', 'sp2');
      service.recordCollection('cell1', 'sp3');
      expect(service.isFullyRestored('cell1'), isTrue);
    });

    // -------------------------------------------------------------------------
    // getAllRestorationLevels
    // -------------------------------------------------------------------------

    test('getAllRestorationLevels returns all cells with species', () {
      service.recordCollection('cell1', 'sp1');
      service.recordCollection('cell2', 'sp2');
      service.recordCollection('cell3', 'sp3');

      final all = service.getAllRestorationLevels();
      expect(all.keys, containsAll(['cell1', 'cell2', 'cell3']));
    });

    test('getAllRestorationLevels returns empty map when no collections', () {
      expect(service.getAllRestorationLevels(), isEmpty);
    });

    test('getAllRestorationLevels returns correct levels per cell', () {
      service.recordCollection('cell1', 'sp1');
      service.recordCollection('cell2', 'sp1');
      service.recordCollection('cell2', 'sp2');

      final all = service.getAllRestorationLevels();
      expect(all['cell1'], closeTo(1 / 3, 0.001));
      expect(all['cell2'], closeTo(2 / 3, 0.001));
    });

    // -------------------------------------------------------------------------
    // loadState
    // -------------------------------------------------------------------------

    test('loadState restores levels correctly', () {
      service.loadState({'cell1': 0.5, 'cell2': 1.0});
      expect(service.getRestorationLevel('cell1'), equals(0.5));
      expect(service.getRestorationLevel('cell2'), equals(1.0));
    });

    test('loadState replaces existing levels', () {
      service.recordCollection('cell1', 'sp1');
      service.loadState({'cell1': 0.66});
      expect(service.getRestorationLevel('cell1'), equals(0.66));
    });

    test('loadState clears previous levels not in new map', () {
      service.recordCollection('cell1', 'sp1');
      service.loadState({'cell2': 0.5});
      expect(service.getRestorationLevel('cell1'), equals(0.0));
      expect(service.getRestorationLevel('cell2'), equals(0.5));
    });

    test('cells in different cells are independent', () {
      service.recordCollection('cell1', 'sp1');
      service.recordCollection('cell2', 'sp1');
      service.recordCollection('cell2', 'sp2');

      expect(service.getRestorationLevel('cell1'), closeTo(1 / 3, 0.001));
      expect(service.getRestorationLevel('cell2'), closeTo(2 / 3, 0.001));
    });
  });
}
