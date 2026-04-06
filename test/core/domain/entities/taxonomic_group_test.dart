import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/taxonomic_group.dart';

void main() {
  group('TaxonomicGroup.fromTaxonomicClass', () {
    test('MAMMALIA → mammals', () {
      expect(TaxonomicGroup.fromTaxonomicClass('MAMMALIA'),
          TaxonomicGroup.mammals);
    });

    test('AVES → birds', () {
      expect(TaxonomicGroup.fromTaxonomicClass('AVES'), TaxonomicGroup.birds);
    });

    test('ACTINOPTERYGII → fish', () {
      expect(TaxonomicGroup.fromTaxonomicClass('ACTINOPTERYGII'),
          TaxonomicGroup.fish);
    });

    test('INSECTA → invertebrates', () {
      expect(TaxonomicGroup.fromTaxonomicClass('INSECTA'),
          TaxonomicGroup.invertebrates);
    });

    test('null → other', () {
      expect(TaxonomicGroup.fromTaxonomicClass(null), TaxonomicGroup.other);
    });

    test('empty string → other', () {
      expect(TaxonomicGroup.fromTaxonomicClass(''), TaxonomicGroup.other);
    });

    test('unknown class → other', () {
      expect(
          TaxonomicGroup.fromTaxonomicClass('PLANTAE'), TaxonomicGroup.other);
    });

    test('case-insensitive matching', () {
      expect(TaxonomicGroup.fromTaxonomicClass('mammalia'),
          TaxonomicGroup.mammals);
    });
  });

  group('TaxonomicGroup enum', () {
    test('has label', () {
      expect(TaxonomicGroup.mammals.label, 'Mammals');
      expect(TaxonomicGroup.birds.label, 'Birds');
      expect(TaxonomicGroup.fish.label, 'Fish');
      expect(TaxonomicGroup.other.label, 'Other');
    });
  });
}
