import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapRootScreen HitTestBehavior', () {
    test(
        'source uses HitTestBehavior.translucent so injected pointer events '
        'reach the GestureDetector when a hierarchy screen is mounted', () {
      final source = File(
        'lib/features/map/presentation/screens/map_root_screen.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('HitTestBehavior.translucent'),
        reason: 'GestureDetector must use translucent so pointer-injected '
            'scale events reach the recognizer even when Positioned.fill '
            'hierarchy child is mounted on top.',
      );
      expect(
        source,
        isNot(contains('HitTestBehavior.deferToChild')),
        reason: 'deferToChild causes hierarchy screen to swallow hit tests.',
      );
    });
  });
}
