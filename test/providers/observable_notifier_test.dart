import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObservableNotifier enforcement', () {
    test('no Notifier subclass bypasses ObservableNotifier', () {
      // Scan all provider files for raw `extends Notifier<` that should be
      // `extends ObservableNotifier<`. This catches future violations at test
      // time — the same way the base class catches them at compile time.
      final providerDir = Directory('lib/providers');
      final violations = <String>[];

      for (final file in providerDir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        // Skip the base class itself.
        if (file.path.contains('observable_notifier.dart')) continue;

        final contents = file.readAsStringSync();
        // Match `extends Notifier<` but not `extends ObservableNotifier<`
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
