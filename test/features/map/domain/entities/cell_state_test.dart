import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';

void main() {
  group('CellRelationship', () {
    test('has present, explored, nearby values', () {
      expect(
          CellRelationship.values,
          containsAll([
            CellRelationship.present,
            CellRelationship.explored,
            CellRelationship.nearby,
          ]));
    });

    test('has exactly 3 values', () {
      expect(CellRelationship.values.length, 3);
    });
  });

  group('CellContents', () {
    test('has empty and hasLoot values', () {
      expect(
          CellContents.values,
          containsAll([
            CellContents.empty,
            CellContents.hasLoot,
          ]));
    });

    test('has exactly 2 values', () {
      expect(CellContents.values.length, 2);
    });
  });

  group('CellState', () {
    test('constructs with relationship and contents', () {
      const state = CellState(
        relationship: CellRelationship.present,
        contents: CellContents.hasLoot,
      );
      expect(state.relationship, CellRelationship.present);
      expect(state.contents, CellContents.hasLoot);
    });

    test('equality', () {
      const a = CellState(
        relationship: CellRelationship.explored,
        contents: CellContents.empty,
      );
      const b = CellState(
        relationship: CellRelationship.explored,
        contents: CellContents.empty,
      );
      expect(a, equals(b));
    });

    test('inequality when relationship differs', () {
      const a = CellState(
        relationship: CellRelationship.present,
        contents: CellContents.empty,
      );
      const b = CellState(
        relationship: CellRelationship.nearby,
        contents: CellContents.empty,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when contents differs', () {
      const a = CellState(
        relationship: CellRelationship.explored,
        contents: CellContents.empty,
      );
      const b = CellState(
        relationship: CellRelationship.explored,
        contents: CellContents.hasLoot,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
