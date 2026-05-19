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

    test('all action ids are known and kebab-case', () {
      final kebabCase = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

      for (final actionId in PlayerActions.all) {
        expect(PlayerActions.isKnown(actionId), isTrue);
        expect(actionId, matches(kebabCase));
      }
    });
  });
}
