import 'dart:io';

import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayerActions', () {
    test('Dart action constants mirror SuperBDD product action ids', () {
      final source = File('product/actions.ts').readAsStringSync();
      final actionIdPattern = RegExp(
        r'\n\s*[A-Za-z0-9_]+:\s*'
        r'(?:navigationAction|viewAction|physicalAction|mutationAction)'
        r'\(\s*\n\s*"([^"]+)"',
      );
      final superBddActionIds = actionIdPattern
          .allMatches(source)
          .map((match) => match.group(1)!)
          .toSet();

      expect(superBddActionIds, isNotEmpty);
      expect(PlayerActions.all, unorderedEquals(superBddActionIds));
    });

    test('includes the present Encounter resolution action', () {
      expect(
        PlayerActions.resolvePresentEncounter,
        'resolve-present-encounter',
      );
    });

    test('uses the existing inspect Cell action without inventing refresh', () {
      expect(PlayerActions.inspectMapCell, 'inspect-map-cell');
      expect(PlayerActions.all, contains('inspect-map-cell'));
      expect(
        PlayerActions.all.where((action) => action.contains('refresh')),
        isEmpty,
      );

      final source = File('product/actions.ts').readAsStringSync();
      expect(source, contains('"Inspect a map cell"'));
      expect(source, contains('"Map cell detail sheet"'));
    });

    test('separates Pack Examination from the Identification Service', () {
      expect(
        PlayerActions.all,
        containsAll(<String>[
          'examine-pack-item',
          'open-identification-service',
          'identify-unidentified-find',
          'reveal-identification',
        ]),
      );

      final source = File('product/actions.ts').readAsStringSync();
      expect(source, contains('"examine-pack-item"'));
      expect(source, contains('"open-identification-service"'));
      expect(
        source,
        contains('without a Villager, Venue, Service, or Property Value'),
      );
      expect(
        source,
        contains('without activating Town as a bottom destination'),
      );
    });

    test('all action ids are known and kebab-case', () {
      final kebabCase = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

      for (final actionId in PlayerActions.all) {
        expect(PlayerActions.isKnown(actionId), isTrue);
        expect(actionId, matches(kebabCase));
      }
    });
  });
}
