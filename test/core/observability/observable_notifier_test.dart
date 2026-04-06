import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObservableNotifier enforcement', () {
    test('no Notifier subclass bypasses ObservableNotifier', () {
      final libDir = Directory('lib');
      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.contains('observable_notifier.dart')) continue;

        final contents = file.readAsStringSync();
        final rawNotifierPattern =
            RegExp(r'extends\s+Notifier<(?!.*ObservableNotifier)');
        if (rawNotifierPattern.hasMatch(contents)) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'These files use raw Notifier instead of ObservableNotifier:\n'
            '${violations.join('\n')}\n\n'
            'All notifiers MUST extend ObservableNotifier<T> to ensure '
            'every state transition is logged. See docs/design.md §6.',
      );
    });
  });
}
